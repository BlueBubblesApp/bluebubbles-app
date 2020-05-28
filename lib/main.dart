import 'dart:async';
import 'dart:convert';

import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/repository/database.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/setup_view.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';

// import './conversation_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'conversation_list.dart';
import 'settings.dart';
import 'singleton.dart';

// void main() => runApp(Main());
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBProvider.db.initDB();
  runApp(Main());
}

class Main extends StatelessWidget with WidgetsBindingObserver {
  const Main({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueBubbles',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        splashFactory: InkRipple.splashFactory,
        // canvasColor: Colors.transparent,
      ),
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  Home({Key key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    // _getContacts();
    Singleton().settings = new Settings();
    Singleton().platform.setMethodCallHandler(_handleFCM);
    SchedulerBinding.instance
        .addPostFrameCallback((_) => Singleton().getSavedSettings());
    WidgetsBinding.instance.addObserver(this);
    _setupNotifications();
    // Singleton().subscribe(() {
    //   if (this.mounted) setState(() {});
    // });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint("closed socket");
      Singleton().closeSocket();
    } else if (state == AppLifecycleState.resumed) {
      Singleton().startSocketIO();
    }
  }

  Future<dynamic> _handleFCM(MethodCall call) async {
    switch (call.method) {
      case "new-server":
        debugPrint("New Server: " + call.arguments.toString());
        debugPrint(call.arguments.toString().length.toString());
        Singleton().settings.serverAddress = call.arguments
            .toString()
            .substring(1, call.arguments.toString().length - 1);
        Singleton().saveSettings(Singleton().settings, true);
        return new Future.value("");
      case "new-message":
        Map<String, dynamic> data = jsonDecode(call.arguments);
        Chat chat = await Chat.findOne({"guid": data["chats"][0]["guid"]});
        if (chat == null) return;
        String title = await chatTitle(chat);
        String message = data["text"].toString();
        if (!data["isFromMe"])
          await _showNotificationWithDefaultSound(0, title, message);

        if (Singleton().processedGUIDS.contains(data["guid"])) {
          debugPrint("contains guid");
          return;
        } else {
          Singleton().processedGUIDS.add(data["guid"]);
        }
        if (data["chats"].length == 0) return new Future.value("");
        Singleton().handleNewMessage(data, chat);
        if (data["isFromMe"]) {
          return new Future.value("");
        }

        return new Future.value("");
      case "updated-message":
        return new Future.value("");
    }
  }

  void _setupNotifications() {
    var initializationSettingsAndroid =
        new AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsIOS = new IOSInitializationSettings();
    var initializationSettings = new InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: _handleSelectNotification);
  }

  Future _handleSelectNotification(String payload) async {
    showDialog(
      context: context,
      builder: (_) {
        return new AlertDialog(
          title: Text("PayLoad"),
          content: Text("Payload : $payload"),
        );
      },
    );
  }

  Future _showNotificationWithDefaultSound(
      int id, String title, String body) async {
    var androidplatformChannelSpecifics = new AndroidNotificationDetails(
        'com.bricktheworld.bluebubbles',
        'BlueBubbles New Messages',
        'Upon receiving push notifications from fcm, this will display a notification',
        importance: Importance.Max,
        priority: Priority.High);

    var iOSplatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidplatformChannelSpecifics, iOSplatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        id, title, body, platformChannelSpecifics,
        payload: 'Default_Sound');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: StreamBuilder(
          stream: Singleton().finishedSetup.stream,
          builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data) {
                getContacts();
                return ConversationList();
              } else {
                return SetupView();
              }
            } else {
              return Container();
            }
          },
        ));
  }
}
