import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/setup_bloc.dart';
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

  /// Public method called from [Home] when the app is opened or resumed
  opened() {
    // If the app is not alive (was previously closed) and the curent chat is not null (a chat is already open)
    // Then mark the current chat as read.
    if (!_isAlive && NotificationManager().chat != null) {
      NotificationManager().switchChat(NotificationManager().chat);
    }

    // Set the app as open and start the socket
    _isAlive = true;
    SocketManager().startSocketIO();

    // Refresh all the chats assuming that the app has already finished setup
    if (SetupBloc().finishedSetup) ChatBloc().refreshChats();
  }

  /// Public method called from [Home] when the app is closed or paused
  close() {
    if (SettingsManager().settings.finishedSetup) {
      // Close the socket and set the isAlive to false
      //
      // NOTE: [closeSocket] does not necessarily close the socket, it simply requests the SocketManager to attempt to do so
      // If there are socket processes using the socket, then it will not close, and will wait until those tasks are done
      _isAlive = false;
      SocketManager().closeSocket();

      // Closes the backgroun thread when the app is fully closed
      // This does not necessarily mean that the isolate will be closed (such as if the app is not fully closed), but it will attempt to do so
      MethodChannelInterface().closeThread();
    }
  }
}
