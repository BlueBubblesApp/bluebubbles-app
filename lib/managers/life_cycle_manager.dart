import 'package:bluebubble_messages/blocs/setup_bloc.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/material.dart';

class LifeCycleManager {
  factory LifeCycleManager() {
    return _manager;
  }

  static final LifeCycleManager _manager = LifeCycleManager._internal();

  bool _isAlive = false;

  bool get isAlive => _isAlive;

  LifeCycleManager._internal() {
    SocketManager().socketProcessUpdater.listen((event) {
      debugPrint("updated socket process " + event.toString());
      if (event.length == 0 && !_isAlive) {
        SocketManager().closeSocket();
      }
    });
  }

  startDownloader() {
    if (SocketManager().socket == null) {
      SocketManager().startSocketIO();
    }
  }

  finishDownloader() {
    if (!_isAlive) SocketManager().closeSocket();
  }

  opened() {
    _isAlive = true;
    SocketManager().startSocketIO();
  }

  close() {
    debugPrint("finished setup ${SettingsManager().settings.finishedSetup}");
    if (SettingsManager().settings.finishedSetup) {
      _isAlive = false;
      SocketManager().closeSocket();
    }
  }
}
