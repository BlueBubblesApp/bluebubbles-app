import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/background_isolate.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/life_cycle_manager.dart';
import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:bluebubble_messages/managers/navigator_manager.dart';
import 'package:bluebubble_messages/managers/notification_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/database.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/layouts/setup/setup_view.dart';
import 'package:cupertino_back_gesture/cupertino_back_gesture.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import './layouts/conversation_list/conversation_list.dart';
import 'layouts/conversation_view/new_chat_creator.dart';
import 'settings.dart';
import 'socket_manager.dart';

// void main() => runApp(Main());
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBProvider.db.initDB();
  initializeDateFormatting('fr_FR', null).then((_) => runApp(Main()));
}

class Main extends StatelessWidget with WidgetsBindingObserver {
  const Main({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: ThemeData(
        primarySwatch: Colors.blue,
        splashFactory: InkRipple.splashFactory,
        textTheme: TextTheme(
          headline1: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          headline2: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          bodyText1: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.normal,
          ),
          bodyText2: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
          ),
          subtitle1: TextStyle(
            color: HexColor('9a9a9f'),
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
          subtitle2: TextStyle(
            color: HexColor('9a9a9f'),
            fontSize: 9,
            fontWeight: FontWeight.normal,
          ),
        ),
        accentColor: HexColor('e5e5ea'),
        dividerColor: HexColor('e5e5ea').withOpacity(0.5),
        backgroundColor: Colors.white,
      ),
      dark: ThemeData(
        primarySwatch: Colors.blue,
        splashFactory: InkRipple.splashFactory,
        textTheme: TextTheme(
          headline1: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
            fontSize: 18,
          ),
          headline2: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          bodyText1: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
          ),
          bodyText2: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
          ),
          subtitle1: TextStyle(
            color: HexColor('36363a'),
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
          subtitle2: TextStyle(
            color: HexColor('36363a'),
            fontSize: 9,
            fontWeight: FontWeight.normal,
          ),
        ),
        accentColor: HexColor('26262a'),
        dividerColor: HexColor('26262a').withOpacity(0.5),
        buttonColor: HexColor("666666"),
        backgroundColor: Colors.black,
        splashColor: Colors.white,
      ),
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
    SettingsManager().init();
    LifeCycleManager().opened();
    // QueueManager().init();
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
    SchedulerBinding.instance
        .addPostFrameCallback((_) => SettingsManager().getSavedSettings());
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
