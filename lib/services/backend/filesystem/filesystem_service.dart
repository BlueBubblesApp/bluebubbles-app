import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:dynamic_cached_fonts/dynamic_cached_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

FilesystemService fs = Get.isRegistered<FilesystemService>() ? Get.find<FilesystemService>() : Get.put(FilesystemService());

class FilesystemService extends GetxService {
  late final Directory appDocDir;
  late final PackageInfo packageInfo;
  final RxBool fontExistsOnDisk = false.obs;

  Future<void> init() async {
    if (!kIsWeb) {
      //ignore: unnecessary_cast, we need this as a workaround
      appDocDir = (kIsDesktop ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory()) as Directory;
      bool? useCustomPath = ss.prefs.getBool("use-custom-path");
      String? customStorePath = ss.prefs.getString("custom-path");
      if (Platform.isWindows && useCustomPath == true && customStorePath != null) {
        appDocDir = Directory(customStorePath);
      }
    }
    packageInfo = await PackageInfo.fromPlatform();
  }

  void checkFont() {
    if (kIsWeb) {
      try {
        DynamicCachedFonts.loadCachedFont(
            "https://github.com/tneotia/tneotia/releases/download/ios-font-2/AppleColorEmoji.ttf",
            fontFamily: "Apple Color Emoji").then((_) {
          fontExistsOnDisk.value = true;
        });
      } on StateError catch (_) {
        fontExistsOnDisk.value = false;
      }
    } else {
      final idbFactory = idbFactoryBrowser;
      idbFactory.open("BlueBubbles.db", version: 1, onUpgradeNeeded: (VersionChangeEvent e) {
        final db = (e.target as OpenDBRequest).result;
        if (!db.objectStoreNames.contains("BBStore")) {
          db.createObjectStore("BBStore");
        }
      }).then((_db) async {
        db = _db;
        final txn = db.transaction("BBStore", idbModeReadOnly);
        final store = txn.objectStore("BBStore");
        Uint8List? bytes = await store.getObject("iosFont") as Uint8List?;
        await txn.completed;

        if (!isNullOrEmpty(bytes)!) {
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
}