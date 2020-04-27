import 'dart:convert';

import 'package:adhara_socket_io/manager.dart';
import 'package:adhara_socket_io/options.dart';
import 'package:adhara_socket_io/socket.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

class Singleton {
  static final Singleton _singleton = Singleton._internal();
  factory Singleton() {
    return _singleton;
  }
  Singleton._internal();

  //Socket io
  SocketIOManager manager;
  SocketIO socket;

  //general data
  List chats = [];
  List<Contact> contacts = <Contact>[];

  //interface with native code
  final platform = const MethodChannel('samples.flutter.dev/fcm');

  //settings
  Settings settings;
  SharedPreferences sharedPreferences;
  String token;

  //setstate for these widgets
  List<Function> subscribers = <Function>[];

  void subscribe(Function cb) {
    _singleton.subscribers.add(cb);
  }

  void notify() {
    debugPrint(
        "notifying subscribers: " + _singleton.subscribers.length.toString());
    for (int i = 0; i < _singleton.subscribers.length; i++) {
      _singleton.subscribers[i]();
    }
    // _singleton.subscribers.forEach((cb) {
    //   cb();
    //   debugPrint("notified subscriber");
    // });
  }

  void getSavedSettings() async {
    _singleton.sharedPreferences = await SharedPreferences.getInstance();
    var result = _singleton.sharedPreferences.getString('Settings');
    if (result != null) {
      Map resultMap = jsonDecode(result);
      _singleton.settings = Settings.fromJson(resultMap);
    }
    _singleton.startSocketIO();
    _singleton.authFCM();
  }

  void saveSettings(Settings settings) async {
    if (_singleton.sharedPreferences == null) {
      _singleton.sharedPreferences = await SharedPreferences.getInstance();
    }
    _singleton.sharedPreferences.setString('Settings', jsonEncode(settings));
    _singleton.startSocketIO();
    _singleton.authFCM();
  }

  void startSocketIO() async {
    if (_singleton.manager == null) {
      _singleton.manager = SocketIOManager();
    }
    if (_singleton.socket != null) {
      _singleton.manager.clearInstance(_singleton.socket);
    }
    debugPrint("Starting socket io with the server: " +
        _singleton.settings.serverAddress);
    try {
      _singleton.socket = await _singleton.manager.createInstance(SocketOptions(
          //Socket IO server URI
          _singleton.settings.serverAddress,
          // nameSpace: "/",
          enableLogging: false,
          transports: [
            Transports.WEB_SOCKET /*, Transports.POLLING*/
          ] //Enable required transport
          ));
      _singleton.socket.onConnectError(
        (error) {
          debugPrint(error);
        },
      );
      _singleton.socket.onConnectTimeout(
        (error) {
          debugPrint(error);
        },
      );
      _singleton.socket.onError(
        (error) {
          debugPrint(error);
        },
      );
      _singleton.socket.onDisconnect(
        (error) {
          debugPrint("Disconnected");
        },
      );
      _singleton.socket.on("chats", (data) {
        debugPrint(data["data"].toString());
        Singleton().chats = data["data"];
        notify();
      });
      debugPrint("connecting...");
      _singleton.socket.connect();
      _singleton.socket.onConnect(
        (data) {
          debugPrint("connected");
          _singleton.socket.emit("add-fcm-device-id", [
            {"deviceId": token, "deviceName": "android-client"}
          ]);
          _singleton.socket.emit("get-chats", []);
        },
      );
      _singleton.socket.on("fcm-device-id-added", (data) {
        debugPrint("fcm device added: " + data.toString());
      });
      _singleton.socket.on("error", (data) {
        debugPrint("an error occurred: " + data.toString());
      });
    } catch (e) {
      debugPrint("FAILED TO CONNECT");
    }
  }

  void closeSocket() {
    _singleton.manager.clearInstance(_singleton.socket);
    _singleton.socket = null;
  }

  Future<void> authFCM() async {
    try {
      final String result =
          await platform.invokeMethod('auth', _singleton.settings.fcmAuthData);
      token = result;
      if (_singleton.socket != null)
        _singleton.socket.emit("set-FCM-token", [token]);
      debugPrint(token);
    } on PlatformException catch (e) {
      token = "Failed to get token: " + e.toString();
      debugPrint(token);
    }
  }
}
