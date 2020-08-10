import 'dart:async';
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/managers/background_isolate.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/navigator_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/layouts/setup/setup_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart' hide Priority;

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:sentry/sentry.dart';

import './layouts/conversation_list/conversation_list.dart';
import 'layouts/conversation_view/new_chat_creator.dart';
import 'socket_manager.dart';

final SentryClient _sentry = SentryClient(
    dsn:
        "https://3123d4f0d82d405190cb599d0e904adc@o373132.ingest.sentry.io/5372783");

bool get isInDebugMode {
  // Assume you're in production mode.
  bool inDebugMode = false;

  // Assert expressions are only evaluated during development. They are ignored
  // in production. Therefore, this code only sets `inDebugMode` to true
  // in a development environment.
  assert(inDebugMode = true);

  return inDebugMode;
}

Future<Null> _reportError(dynamic error, dynamic stackTrace) async {
  // Print the exception to the console.
  debugPrint('Caught error: $error');
  if (isInDebugMode) {
    // Print the full stacktrace in debug mode.
    debugPrint(stackTrace);
  } else {
    // Send the Exception and Stacktrace to Sentry in Production mode.
    _sentry.captureException(
      exception: error,
      stackTrace: stackTrace,
    );
  }
}

Future<Null> main() async {
  // This captures errors reported by the Flutter framework.
  FlutterError.onError = (FlutterErrorDetails details) async {
    if (isInDebugMode) {
      // In development mode simply print to console.
      FlutterError.dumpErrorToConsole(details);
    } else {
      // In production mode report to the application zone to report to
      // Sentry.
      Zone.current.handleUncaughtError(details.exception, details.stack);
    }
  };

  WidgetsFlutterBinding.ensureInitialized();
  await DBProvider.db.initDB();
  await initializeDateFormatting('fr_FR', null);
  runZonedGuarded<Future<Null>>(() async {
    runApp(Main());
  }, (Object error, StackTrace stackTrace) async {
    // Whenever an error occurs, call the `_reportError` function. This sends
    // Dart errors to the dev console or Sentry depending on the environment.
    await _reportError(error, stackTrace);
  });
}

class Main extends StatelessWidget with WidgetsBindingObserver {
  const Main({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: whiteLightTheme,
      dark: oledDarkTheme,
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp(
        title: 'BlueBubbles',
        theme: theme,
        darkTheme: darkTheme,
        navigatorKey: NavigatorManager().navigatorKey,
        home: Home(),
      ),
    );
  }
}

class Home extends StatefulWidget {
  Home({Key key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    LifeCycleManager().opened();
    // QueueManager().init();
    SettingsManager().init();
    MethodChannelInterface().init(context);
    BackgroundIsolateInterface.initialize();
    ReceiveSharingIntent.getInitialMedia()
        .then((List<SharedMediaFile> value) async {
      if (value == null) return;

      if (!await Permission.storage.request().isGranted) return;

      List<File> attachments = <File>[];
      if (value != null) {
        value.forEach((element) {
          debugPrint("${element.path}");
          attachments.add(File(element.path));
        });
      }

      Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(
            builder: (context) => NewChatCreator(
              attachments: attachments,
              isCreator: true,
            ),
          ),
          (route) => route.isFirst);
    });
    ReceiveSharingIntent.getInitialText().then((String text) {
      if (text == null) return;

      Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(
            builder: (context) => NewChatCreator(
              existingText: text,
              isCreator: true,
            ),
          ),
          (route) => route.isFirst);
    });

    MethodChannelInterface().invokeMethod("get-starting-intent").then((value) {
      debugPrint("starting intent " + value.toString());
      if (value != null) {
        MethodChannelInterface().openChat(value.toString());
      }
    });

    NotificationManager().createNotificationChannel();
    SchedulerBinding.instance.addPostFrameCallback(
        (_) => SettingsManager().getSavedSettings(context: context));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      LifeCycleManager().close();
    } else if (state == AppLifecycleState.resumed) {
      LifeCycleManager().opened();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder(
        stream: SocketManager().finishedSetup.stream,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data) {
              ContactManager().getContacts();
              return ConversationList(
                showArchivedChats: false,
              );
            } else {
              return SetupView();
            }
          } else {
            return Container();
          }
        },
      ),
    );
  }
}
