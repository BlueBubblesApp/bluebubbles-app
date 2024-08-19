import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:on_exit/init.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';
import 'package:window_manager/window_manager.dart';

class StartupTasks {

  static final Completer<void> uiReady = Completer<void>();

  static Future<void> waitForUI() async {
    await uiReady.future;
  }

  static Future<void> initStartupServices({bool isBubble = false}) async {
    debugPrint("Initializing startup services...");
    
    // First, initialize the filesystem service as it's used by other necessary services
    await fs.init();

    // Initialize the logger so we can start logging things immediately
    await Logger.init();
    Logger.debug("Initializing startup services...");

    // Check if another instance is running (Linux Only).
    // Automatically handled on Windows (I think)
    await StartupTasks.checkInstanceLock();

    // Setup the settings service
    await ss.init();

    // The next thing we need to do is initialize the database.
    // If the database is not initialized, we cannot do anything.
    await Database.init();

    // Load FCM data into settings from the database
    // We only need to do this for the main startup
    ss.getFcmData();
    
    // We then have to initialize all the services that the app will use.
    // Order matters here as some services may rely on others. For instance,
    // The MethodChannel service needs the database to be initialized to handle events.
    // The Lifecycle service needs the MethodChannel service to be initialized to send events.
    await mcs.init();
    await ls.init(isBubble: isBubble);
    await ts.init();
    
    if (!kIsWeb) {
      await cs.init();
    }

    await notif.init();
    await intents.init();
  }

  static Future<void> initIsolateServices() async {
    debugPrint("Initializing isolate services...");
    await fs.init(headless: true);
    await Logger.init();
    Logger.debug("Initializing isolate services...");
    await ss.init(headless: true);
    await Database.init();
    await mcs.init(headless: true);
    await ls.init(headless: true);
  }

  static Future<void> initIncrementalSyncServices() async {
    debugPrint("Initializing incremental sync services...");
    await fs.init();
    await Logger.init();
    Logger.debug("Initializing incremental sync services...");
    await ss.init();
    await Database.init();
  }

  static Future<void> onStartup() async {
    if (!ss.settings.finishedSetup.value) return;

    if (!kIsDesktop) {
      chats.init();
      socket;
    }

    // Fetch server details for the rest of the app.
    // We only need to fetch it on startup since the metadata shouldn't change.
    await ss.getServerDetails(refresh: true);

    // Only register FCM device on startup
    await fcm.registerDevice();

    // We don't need to check for updates immediately, so delay it so other
    // code has a chance to run and we don't block the UI thread.
    Future.delayed(const Duration(seconds: 10), () {
      try {
        ss.checkServerUpdate();
      } catch (ex, stack) {
        Logger.warn("Failed to check for server update!", error: ex, trace: stack);
      }

      try {
        ss.checkClientUpdate();
      } catch (ex, stack) {
        Logger.warn("Failed to check for client update!", error: ex, trace: stack);
      }
    });
  }

  static Future<void> checkInstanceLock() async {
    if (!kIsDesktop || !Platform.isLinux) return;
    Logger.debug("Starting process with PID $pid");

    final lockFile = File(join(fs.appDocDir.path, 'bluebubbles.lck'));
    final instanceFile = File(join(fs.appDocDir.path, '.instance'));
    onExit(() {
      if (lockFile.existsSync()) lockFile.deleteSync();
    });

    if (!lockFile.existsSync()) {
      lockFile.createSync();
    }
    if (!instanceFile.existsSync()) {
      instanceFile.createSync();
    }

    Logger.debug("Lockfile at ${lockFile.path}");
    String _pid = lockFile.readAsStringSync();
    String ps = Process.runSync('ps', ['-p', _pid]).stdout;
    if (kReleaseMode && "$pid" != _pid && ps.endsWith('bluebubbles\n')) {
      Logger.debug("Another instance is running. Sending foreground signal");
      instanceFile.openSync(mode: FileMode.write).closeSync();
      exit(0);
    }

    lockFile.writeAsStringSync("$pid");
    instanceFile.watch(events: FileSystemEvent.modify).listen((event) async {
      Logger.debug("Got Signal to go to foreground");
      doWhenWindowReady(() async {
        await windowManager.show();
        List<Tuple2<String, String>?> widAndNames = await (await Process.start('wmctrl', ['-pl']))
            .stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .map((line) => line.replaceAll(RegExp(r"\s+"), " ").split(" "))
            .map((split) => split[2] == "$pid" ? Tuple2(split.first, split.last) : null)
            .where((tuple) => tuple != null)
            .toList();

        for (Tuple2<String, String>? window in widAndNames) {
          if (window?.item2 == "BlueBubbles") {
            Process.runSync('wmctrl', ['-iR', window!.item1]);
            break;
          }
        }
      });
    });
  }
}