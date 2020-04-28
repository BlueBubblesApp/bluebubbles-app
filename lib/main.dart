import 'dart:async';
import 'dart:convert';

import 'package:bluebubble_messages/SQL/Repositories/RepoService.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contacts_service/contacts_service.dart';

import './conversation_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'SQL/Models/Chats.dart';
import 'SQL/Models/Messages.dart' as Message;
import 'SQL/Repositories/DatabaseCreator.dart';
import 'hex_color.dart';
import 'settings.dart';
import 'singleton.dart';

// void main() => runApp(Main());
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseCreator().initDatabase();
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
    _getContacts();
    Singleton().settings = new Settings();
    // Singleton().getSavedSettings();
    Singleton().platform.setMethodCallHandler(_handleFCM);
    SchedulerBinding.instance
        .addPostFrameCallback((_) => Singleton().getSavedSettings());
    WidgetsBinding.instance.addObserver(this);
    _setupNotifications();
    Singleton().subscribe(() {
      if (this.mounted) setState(() {});
    });
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
      // Singleton().manager.clearInstance(Singleton().socket);
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
        Singleton().saveSettings(Singleton().settings);
        return new Future.value("");
      case "new-message":
        Map<String, dynamic> data = jsonDecode(call.arguments);
        Singleton().handleNewMessage(data);
        debugPrint("New Message: " + data.toString());
        String chat = data["from"]["id"].toString();
        String message = data["text"].toString();
        debugPrint("New notification: " + data.toString());

        await _showNotificationWithDefaultSound(0, chat, message);
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // await _showNotificationWithDefaultSound(0, "test", "body");
          debugPrint("getting chats");
          List<Chat> chats = await RepositoryServiceChats.getAllChats();
          debugPrint("got chats");
        },
      ),
      body: ConversationList(),
    );
  }

  void _getContacts() async {
    if (await Permission.contacts.request().isGranted) {
      debugPrint("Contacts granted");
      var contacts =
          (await ContactsService.getContacts(withThumbnails: false)).toList();
      Singleton().contacts = contacts;
      setState(() {});

      // Lazy load thumbnails after rendering initial contacts.
      for (final Contact contact in Singleton().contacts) {
        ContactsService.getAvatar(contact).then((avatar) {
          if (avatar == null) return; // Don't redraw if no change.
          setState(() => contact.avatar = avatar);
        });
      }
    }
  }
}
