import 'package:bluebubble_messages/blocs/setup_bloc.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/material.dart';

class LifeCycleManager {
  factory LifeCycleManager() {
    return _manager;
  }

  static final LifeCycleManager _manager = LifeCycleManager._internal();

  LifeCycleManager._internal();

  bool _isAlive = false;

  bool get isAlive => _isAlive;

  startDownloader() {
    opened();
  }

  finishDownloader() {
    if (!_isAlive &&
        SocketManager().attachmentDownloaders.length == 0 &&
        SocketManager().attachmentSenders.length == 0) {
      close();
    }
  }

  opened() {
    _isAlive = true;
    if (SocketManager().socket == null) SocketManager().startSocketIO();
  }

  close() {
    _isAlive = false;
    debugPrint("finished setup ${SettingsManager().settings.finishedSetup}");
    if (SocketManager().attachmentDownloaders.length == 0 &&
        SocketManager().attachmentSenders.length == 0 &&
        SettingsManager().settings.finishedSetup) {
      SocketManager().closeSocket();
    }
  }
}
