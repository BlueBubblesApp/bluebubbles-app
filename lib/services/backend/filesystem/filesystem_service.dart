import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/services/ui/contact_service.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart' hide Database;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slugify/slugify.dart';
import 'package:universal_io/io.dart';

FilesystemService fs = Get.isRegistered<FilesystemService>() ? Get.find<FilesystemService>() : Get.put(FilesystemService());

class FilesystemService extends GetxService {
  late Directory appDocDir;
  late final PackageInfo packageInfo;
  AndroidDeviceInfo? androidInfo;
  late final idb.Database webDb;
  late final Uint8List noVideoPreviewIcon;
  late final Uint8List unplayableVideoIcon;
  final RxBool fontExistsOnDisk = false.obs;

  Future<String> get downloadsDirectory async {
    if (kIsWeb) throw "Cannot get downloads directory on web!";

    String filePath = "/storage/emulated/0/Download/";
    if (kIsDesktop) {
      filePath = (await getDownloadsDirectory())!.path;
    }

    return filePath;
  }

  Future<void> init({bool headless = false}) async {
    if (!kIsWeb) {
      //ignore: unnecessary_cast, we need this as a workaround
      appDocDir = (kIsDesktop ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory()) as Directory;
      if (kIsDesktop && Platform.isWindows) {
        final String appDataRoot = joinAll(split(appDocDir.absolute.path).slice(0, 4));
        final Directory msStoreLocation = Directory(join(
            appDataRoot,
            "Local",
            "Packages",
            "23344BlueBubbles.BlueBubbles_2fva2ntdzvhtw",
            "LocalCache",
            "Roaming",
            "BlueBubbles",
            "bluebubbles"));
        if (!appDocDir.existsSync() && msStoreLocation.existsSync()) {
          appDocDir = msStoreLocation;
        }
      }
      if (!headless) {
        final file = await rootBundle.load("assets/images/no-video-preview.png");
        noVideoPreviewIcon = file.buffer.asUint8List();
        final file2 = await rootBundle.load("assets/images/unplayable-video.png");
        unplayableVideoIcon = file2.buffer.asUint8List();
      }
    }
    packageInfo = await PackageInfo.fromPlatform();
    if (!headless && Platform.isAndroid) {
      androidInfo = await DeviceInfoPlugin().androidInfo;
    }
  }

  void checkFont() async {
    if (!kIsWeb) {
      final file = File("${fs.appDocDir.path}/font/apple.ttf");
      final exists = await file.exists();
      if (exists) {
        final bytes = await file.readAsBytes();
        fontExistsOnDisk.value = true;
        final fontLoader = FontLoader("Apple Color Emoji");
        final cachedFontBytes = ByteData.view(bytes.buffer);
        fontLoader.addFont(
          Future<ByteData>.value(cachedFontBytes),
        );
        await fontLoader.load();
      }
    } else {
      final idbFactory = idbFactoryBrowser;
      idbFactory.open("BlueBubbles.db", version: 1, onUpgradeNeeded: (idb.VersionChangeEvent e) {
        final db = (e.target as idb.OpenDBRequest).result;
        if (!db.objectStoreNames.contains("BBStore")) {
          db.createObjectStore("BBStore");
        }
      }).then((_db) async {
        webDb = _db;
        final txn = webDb.transaction("BBStore", idb.idbModeReadOnly);
        final store = txn.objectStore("BBStore");
        Uint8List? bytes = await store.getObject("iosFont") as Uint8List?;
        await txn.completed;

        if (!isNullOrEmpty(bytes)) {
          fontExistsOnDisk.value = true;
          final fontLoader = FontLoader("Apple Color Emoji");
          final cachedFontBytes = ByteData.view(bytes!.buffer);
          fontLoader.addFont(
            Future<ByteData>.value(cachedFontBytes),
          );
          await fontLoader.load();
        }
      });
    }
  }

  void deleteDB() {
    if (kIsWeb) return;
    Database.reset();
    cs.contacts.clear();
  }

  String uriToFilename(String? uri, String? mimeType) {
    // Handle any unknown cases
    String? ext = mimeType != null ? mimeType.split('/')[1] : null;
    ext = (ext != null && ext.contains('+')) ? ext.split('+')[0] : ext;
    if (uri == null) return (ext != null) ? 'unknown.$ext' : 'unknown';

    // Get the filename
    String filename = uri;
    if (filename.contains('/')) {
      filename = filename.split('/').last;
    }

    // Get the extension
    if (filename.contains('.')) {
      List<String> split = filename.split('.');
      ext = split[1];
      filename = split[0];
    }

    // Slugify the filename
    filename = slugify(filename, delimiter: '_');

    // Rebuild the filename
    return (ext != null && ext.isNotEmpty) ? '$filename.$ext' : filename;
  }

  void copyDirectory(Directory source, Directory destination) =>
    source.listSync(recursive: false).forEach((element) async {
      if (element is Directory) {
        Directory newDirectory = Directory(join(destination.absolute.path, basename(element.path)));
        newDirectory.createSync();
        Logger.info("Created new directory ${basename(element.path)}");

        copyDirectory(element.absolute, newDirectory);
      } else if (element is File) {
        element.copySync(join(destination.path, basename(element.path)));
        Logger.info("Created file ${basename(element.path)}");
      }
    });

  Future<String> saveToDownloads(File file) async {
    if (kIsWeb) throw "Cannot save file on web!";

    final String filename = basename(file.path);
    final String downloadsDir = await downloadsDirectory;
    final String newPath = join(downloadsDir, filename);
    await file.copy(newPath);
    return newPath;
  }
}