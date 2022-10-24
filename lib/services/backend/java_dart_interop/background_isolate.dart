import 'dart:ui';

import 'package:bluebubbles/app/layouts/startup/upgrading_db.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:universal_io/io.dart';

class BackgroundIsolate {
  static void initialize() {
    CallbackHandle callbackHandle = PluginUtilities.getCallbackHandle(backgroundIsolateEntrypoint)!;
    mcs.invokeMethod("initialize-background-handle", {"handle": callbackHandle.toRawHandle()});
  }
}

@pragma('vm:entry-point')
backgroundIsolateEntrypoint() async {
  // can't use logger here
  debugPrint("(ISOLATE) Starting up...");
  WidgetsFlutterBinding.ensureInitialized();
  ls.isUiThread = false;
  await ss.init(headless: true);
  await fs.init();
  await mcs.init(headless: true);
  debugPrint("Trying to attach to an existing ObjectBox store");
  try {
    store = Store.attach(getObjectBoxModel(), join(fs.appDocDir.path, 'objectbox'));
  } catch (e, s) {
    debugPrint(e.toString());
    debugPrint(s.toString());
    debugPrint("Failed to attach to existing store, opening from path");
    try {
      store = await openStore(directory: join(fs.appDocDir.path, 'objectbox'));
    } catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());
    }
  }
  debugPrint("Opening boxes");
  attachmentBox = store.box<Attachment>();
  chatBox = store.box<Chat>();
  contactBox = store.box<Contact>();
  fcmDataBox = store.box<FCMData>();
  handleBox = store.box<Handle>();
  messageBox = store.box<Message>();
  scheduledBox = store.box<ScheduledMessage>();
  themeBox = store.box<ThemeStruct>();
  storeStartup.complete();
}
