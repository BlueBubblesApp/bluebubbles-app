import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/services/backend/java_dart_interop/method_channel_service.dart';
import 'package:characters/characters.dart';
import 'package:crypto/crypto.dart';
import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart' hide Database;
import 'package:io/io.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slugify/slugify.dart';
import 'package:universal_io/io.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
FilesystemService get FilesystemSvc => GetIt.I<FilesystemService>();

class FilesystemService {
  /// The default Android downloads directory path.
  static const String androidDownloadsPath = '/storage/emulated/0/Download/';

  late Directory appDocDir;
  late final PackageInfo packageInfo;
  late Directory _sysTemp;
  AndroidDeviceInfo? androidInfo;
  late final idb.Database webDb;
  late final Uint8List noVideoPreviewIcon;
  late final Uint8List unplayableVideoIcon;
  final RxBool fontExistsOnDisk = false.obs;

  /// The platform downloads directory. On Android returns [androidDownloadsPath];
  /// on desktop resolves via path_provider.
  Future<String> get downloadsDirectory async {
    if (kIsWeb) throw "Cannot get downloads directory on web!";

    String filePath = androidDownloadsPath;
    if (kIsDesktop) {
      filePath = (await getDownloadsDirectory())!.path;
    }

    return filePath;
  }

  /// The OS-managed system temporary directory (cached at init time).
  Directory get sysTemp => _sysTemp;
  String get sysTempPath => _sysTemp.path;

  /// The app-scoped temporary directory inside [appDocDir].
  String get appTempPath => join(appDocDir.path, 'temp');
  Directory get appTemp => Directory(appTempPath);

  // ---------------------------------------------------------------------------
  // Named app-doc sub-directory paths
  // ---------------------------------------------------------------------------

  String get attachmentsPath => join(appDocDir.path, 'attachments');
  String get avatarsPath => join(appDocDir.path, 'avatars');
  String get messagesPath => join(appDocDir.path, 'messages');
  String get fontPath => join(appDocDir.path, 'font');
  String get soundsPath => join(appDocDir.path, 'sounds');
  String get logsPath => join(appDocDir.path, 'logs');
  String get contactAvatarsPath => join(appDocDir.path, 'contact_avatars');
  String get customBackgroundsPath => join(appDocDir.path, 'custom_backgrounds');
  String get urlPreviewsPath => join(appDocDir.path, 'url_previews');

  /// Returns the path for a cached URL preview image identified by its MD5 hash.
  String urlPreviewImagePath(String md5) => join(urlPreviewsPath, md5);

  /// Downloads and caches a URL preview image. Computes an MD5 hash of the raw
  /// bytes and uses it as the filename so that identical images across different
  /// messages share a single file. Returns the hex MD5 string.
  Future<String> saveUrlPreviewImage(Uint8List bytes) async {
    if (kIsWeb) throw 'saveUrlPreviewImage is not supported on web';
    final hash = md5.convert(bytes).toString();
    final dir = Directory(urlPreviewsPath);
    await dir.create(recursive: true);
    final file = File(join(urlPreviewsPath, hash));
    if (!file.existsSync()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return hash;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Strips non-alphanumeric characters from [guid] so it is safe for use as
  /// a filesystem path component (matches the pattern used by AvatarCrop, etc.).
  static String sanitizeGuid(String guid) => guid.characters.where((c) => c.isAlphabetOnly || c.isNumericOnly).join();

  /// Returns the canonical path where a chat's group avatar is stored.
  /// The file does not necessarily exist yet; callers must create it if needed.
  String chatAvatarPath(String chatGuid) => join(avatarsPath, sanitizeGuid(chatGuid), 'avatar.jpg');

  /// Resolves an existing custom background for a chat using the same folder
  /// layout as the background cropper.
  String? getExistingChatBackgroundPath(String chatGuid) {
    if (kIsWeb) return null;

    final sanitizedGuid = sanitizeGuid(chatGuid);
    final directory = Directory(join(customBackgroundsPath, sanitizedGuid));
    if (!directory.existsSync()) return null;

    final candidates = directory
        .listSync()
        .whereType<File>()
        .where((file) => basename(file.path).startsWith('background'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    return candidates.isEmpty ? null : candidates.first.path;
  }

  /// Strips the Android internal storage prefix from [path] for display.
  /// Returns [path] unchanged on non-Android platforms.
  String toDisplayPath(String path) {
    if (!kIsWeb && Platform.isAndroid) {
      return path.replaceAll('/storage/emulated/0/', '');
    }
    return path;
  }

  Future<void> init({bool headless = false}) async {
    if (!kIsWeb) {
      //ignore: unnecessary_cast, we need this as a workaround
      appDocDir = (kIsDesktop ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory());
      if (isMsix) {
        final String appDataRoot = joinAll(split(appDocDir.absolute.path).slice(0, 4));
        // Family name (Name_PublisherHash) from the install dir; hash varies per variant.
        final exeSegments = split(Platform.resolvedExecutable);
        final fullNameParts = exeSegments[exeSegments.indexOf('WindowsApps') + 1].split('_');
        final packageFamilyName = '${fullNameParts.first}_${fullNameParts.last}';
        final Directory msixLocation = Directory(join(appDataRoot, "Local", "Packages", packageFamilyName, "LocalCache",
            "Roaming", "BlueBubbles", "bluebubbles"));
        // Check if the non-msix directory exists
        final Directory nonMsixLocation = Directory(join(appDataRoot, "Roaming", "BlueBubbles", "bluebubbles"));
        if (!msixLocation.existsSync() && nonMsixLocation.existsSync()) {
          if (!headless) await StartupTasks.setSplashStatus("Copying data from previous version...");
          await copyPath(nonMsixLocation.path, msixLocation.path);
        }
        appDocDir = msixLocation;
      }
      if (!headless) {
        final file = await rootBundle.load("assets/images/no-video-preview.png");
        noVideoPreviewIcon = file.buffer.asUint8List();
        final file2 = await rootBundle.load("assets/images/unplayable-video.png");
        unplayableVideoIcon = file2.buffer.asUint8List();
      }
      _sysTemp = await getTemporaryDirectory();
    }
    packageInfo = await PackageInfo.fromPlatform();
    if (!headless && Platform.isAndroid) {
      androidInfo = await DeviceInfoPlugin().androidInfo;
    }
  }

  void checkFont() async {
    if (!kIsWeb) {
      final file = File(join(fontPath, 'apple.ttf'));
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
    // Contacts are now managed by ContactServiceV2 and don't need manual clearing
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

  Future<String> saveToDownloads(File file, {String mimeType = 'application/octet-stream'}) async {
    if (kIsWeb) throw "Cannot save file on web!";

    final String filename = basename(file.path);

    if (kIsDesktop) {
      // On desktop, path_provider resolves the real OS Downloads folder.
      final String downloadsDir = await downloadsDirectory;
      final String newPath = join(downloadsDir, filename);
      await file.copy(newPath);
      return newPath;
    } else {
      // On Android, use MediaStore.Downloads (API 29+) or direct file copy (older).
      try {
        await MethodChannelSvc.actions.saveFileToDownloads(
          filePath: file.path,
          fileName: filename,
          mimeType: mimeType,
        );
        return filename;
      } catch (_) {
        // Fallback: direct file copy to the public Downloads directory.
        final String newPath = join(androidDownloadsPath, filename);
        await file.copy(newPath);
        return newPath;
      }
    }
  }
}
