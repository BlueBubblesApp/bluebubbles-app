import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';

/// [LifeCycleManager] is responsible for keeping track of when the app is open and when it is closed
///
/// It helps with managing the [SocketManager] socket by closing it and opening it when the app is closed nd when it isn't
/// This class is a singleton
class LifeCycleManager {
  factory LifeCycleManager() {
    return _manager;
  }

  static final LifeCycleManager _manager = LifeCycleManager._internal();

  /// Private variable for whether the app is closed or open
  bool _isAlive = false;

  bool get isAlive => _isAlive;

  LifeCycleManager._internal() {
    // Listen to the socket processes that are updated
    SocketManager().socketProcessUpdater.listen((event) {
      // If there are no more socket processes, then we can safely close the socket
      if (event.length == 0 && !_isAlive) {
        SocketManager().closeSocket();
      }
    });
  }

  /// If we need to download in the background, then we can start the socket
  startDownloader() {
    if (SocketManager().socket == null) {
      SocketManager().startSocketIO();
    }
  }

  // When the downloader is finished, we can close the socket again
  finishDownloader() {
    if (!_isAlive) SocketManager().closeSocket();
  }

  //
  opened() {
    if (!_isAlive && NotificationManager().chat != null) {
      NotificationManager().switchChat(NotificationManager().chat);
    }
    _isAlive = true;
    SocketManager().startSocketIO();
    ChatBloc().refreshChats();
  }

  close() {
    if (SettingsManager().settings.finishedSetup) {
      _isAlive = false;
      SocketManager().closeSocket();
      MethodChannelInterface().closeThread();
    }
  }
}
