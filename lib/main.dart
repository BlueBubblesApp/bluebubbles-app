import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhara_socket_io/adhara_socket_io.dart';

import './conversation_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hex_color.dart';
import 'settings.dart';

void main() => runApp(Main());

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
  SocketIOManager manager;
  SocketIO socket;
  static const platform = const MethodChannel('samples.flutter.dev/fcm');
  Settings _settings;
  SharedPreferences _prefs;
  String token;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  List chats = [];

  @override
  void initState() {
    super.initState();
    _settings = new Settings();
    // _getSavedSettings();
    platform.setMethodCallHandler(_handleFCM);
    SchedulerBinding.instance.addPostFrameCallback((_) => _getSavedSettings());
    WidgetsBinding.instance.addObserver(this);
    _setupNotifications();
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
      manager.clearInstance(socket);
    } else if (state == AppLifecycleState.resumed) {
      startSocketIO();
    }
  }

  void _getSavedSettings() async {
    _prefs = await SharedPreferences.getInstance();
    var result = _prefs.getString('Settings');
    if (result != null) {
      Map resultMap = jsonDecode(result);
      _settings = Settings.fromJson(resultMap);
    }
    _initSocketConnection();
    authFCM();
  }

  void _saveSettings(Settings settings) async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    _prefs.setString('Settings', jsonEncode(settings));
    _initSocketConnection();
    authFCM();
  }

  _initSocketConnection() {
    if (_settings.serverAddress == "") {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              "Server address",
              style: TextStyle(
                color: Colors.white,
              ),
            ),
            content: Container(
              child: Text(
                "Go to settings or scan qr code on your mac server to get server address",
                style: TextStyle(
                  color: Color.fromARGB(255, 100, 100, 100),
                ),
              ),
            ),
            backgroundColor: HexColor('26262a'),
            actions: <Widget>[
              FlatButton(
                child: Text("Ok"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      startSocketIO();
    }
  }

  void startSocketIO() async {
    if (manager == null) {
      manager = SocketIOManager();
    }
    if (socket != null) {
      manager.clearInstance(socket);
    }
    debugPrint(
        "Starting socket io with the server: " + _settings.serverAddress);
    try {
      socket = await manager.createInstance(SocketOptions(
          //Socket IO server URI
          _settings.serverAddress,
          // nameSpace: "/",
          enableLogging: false,
          transports: [
            Transports.WEB_SOCKET /*, Transports.POLLING*/
          ] //Enable required transport
          ));
      socket.onConnectError(
        (error) {
          Scaffold.of(context).showSnackBar(
            SnackBar(
              content: Text("Connection Failed :("),
            ),
          );
        },
      );
      socket.onConnectTimeout(
        (error) {
          debugPrint(error);
          Scaffold.of(context).showSnackBar(
            SnackBar(
              content: Text("Connection Timed out :("),
            ),
          );
        },
      );
      socket.onError(
        (error) {
          debugPrint(error);
          Scaffold.of(context).showSnackBar(
            SnackBar(
              content: Text("Connection to Server encountered an error :("),
            ),
          );
        },
      );
      socket.onDisconnect(
        (error) {
          debugPrint(error);
          Scaffold.of(context).showSnackBar(
            SnackBar(
              content: Text("Disconnected from Server D:"),
            ),
          );
        },
      );
      socket.on("chats", (data) {
        debugPrint(data["data"].toString());
        chats = data["data"];
        chats.forEach((f) {
          debugPrint(f.toString());
        });
        setState(() {});
      });
      debugPrint("connecting...");
      socket.connect();
      socket.onConnect(
        (data) {
          debugPrint("connected");
          socket.emit("add-fcm-device-id", [
            {"deviceId": token}
          ]);
          socket.emit("get-chats", []);
          // Scaffold.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text("Connected to Server :)"),
          //   ),
          // );
        },
      );
      socket.on("fcm-device-id-added", (data) {
        debugPrint("fcm device added: " + data.toString());
      });
      socket.on("error", (data) {
        debugPrint("an error occurred: " + data.toString());
      });
    } catch (e) {
      debugPrint("FAILED TO CONNECT");
    }
  }

  Future<void> authFCM() async {
    try {
      final String result =
          await platform.invokeMethod('auth', _settings.fcmAuthData);
      token = result;
      if (socket != null) socket.emit("set-FCM-token", [token]);
      debugPrint(token);
    } on PlatformException catch (e) {
      token = "Failed to get token: " + e.toString();
      debugPrint(token);
    }
  }

  Future<dynamic> _handleFCM(MethodCall call) async {
    switch (call.method) {
      case "new-server":
        debugPrint("New Server: " + call.arguments.toString());
        debugPrint(call.arguments.toString().length.toString());
        _settings.serverAddress = call.arguments
            .toString()
            .substring(1, call.arguments.toString().length - 1);
        _saveSettings(_settings);
        return new Future.value("");
      case "new-message":
        Map<String, dynamic> data = jsonDecode(call.arguments);
        debugPrint("New Message: " + data.toString());
        String chat = data["from"]["id"].toString();
        String message = data["text"].toString();
        // debugPrint("New notification: " + chat);
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
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'com.bricktheworld.bluebubbles',
        'BlueBubbles New Messages',
        'Upon receiving push notifications from fcm, this will display a notification',
        importance: Importance.Max,
        priority: Priority.High);

    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        id, title, body, platformChannelSpecifics,
        payload: 'Default_Sound');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _showNotificationWithDefaultSound(0, "test", "body");
        },
      ),
      body: ConversationList(
        onPressed: () {
          authFCM();
        },
        saveSettings: (Settings settings) {
          _settings = settings;
          // startSocketIO();
          _saveSettings(_settings);
          debugPrint("saved settings");
        },
        settings: _settings,
        sendSocketMessage: (String event, String message, Function callback) {
          // socketIO.sendMessage(event, null);
          socket.emit(event, null);
        },
        chats: chats,
        requestMessages: (params, cb) {
          socket.emit("get-chat-messages", [params]);
          socket.on("chat-messages", (data) {
            cb(data["data"]);
          });
        },
      ),
    );
  }
}
