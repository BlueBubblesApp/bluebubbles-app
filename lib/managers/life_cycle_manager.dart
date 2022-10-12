import 'dart:async';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/chat/chat_controller.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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

  bool isBubble = false;

  final StreamController<bool> _stream = StreamController.broadcast();
  Stream<bool> get stream => _stream.stream;

  LifeCycleManager._internal();

  /// Public method called from [Home] when the app is opened or resumed
  opened() {
    ChatController? chat = ChatManager().getActiveDeadController();

    // If the app is not alive (was previously closed) and the curent chat is not null (a chat is already open)
    // Then mark the current chat as read.
    if (!_isAlive && ChatManager().activeChat != null && !kIsDesktop && chat != null) {
      ChatManager().clearChatNotifications(ChatManager().activeChat!.chat);
    }

    ChatManager().setActiveToAlive();

    // Set the app as open and start the socket
    updateStatus(true);
    if (!kIsDesktop) {
      // socket.startSocketIO();
    }

    if (kIsDesktop) {
      EventDispatcher().emit('focus-keyboard', null);
    }

    // Refresh all the chats assuming that the app has already finished setup
    if (settings.settings.finishedSetup.value && !kIsDesktop) {
      ChatBloc().resumeRefresh();
    }
  }

  /// Public method called from [Home] when the app is closed or paused
  close() {
    // When we close we want to set the currently active chat to be un-alive
    ChatManager().setActiveToDead();

    if (settings.settings.finishedSetup.value) {
      // Close the socket and set the isAlive to false
      //
      // NOTE: [closeSocket] does not necessarily close the socket, it simply requests the SocketManager to attempt to do so
      // If there are socket processes using the socket, then it will not close, and will wait until those tasks are done
      updateStatus(false);
      if (!kIsDesktop && !kIsWeb) {
        socket.closeSocket();

        // Closes the background thread when the app is fully closed
        // This does not necessarily mean that the isolate will be closed (such as if the app is not fully closed), but it will attempt to do so
        MethodChannelInterface().closeThread();
      }
    }
  }

  /// Helper method to update the alive status and send the new status to the stream
  updateStatus(bool newStatus) {
    // We don't want to send things to the stream unless they are new
    if (_isAlive != newStatus) {
      _isAlive = newStatus;
      _stream.sink.add(_isAlive);
    }
  }

  dispose() {
    _stream.close();
  }
}
