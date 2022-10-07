import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/attachment_sender.dart';
import 'package:bluebubbles/helpers/crypto.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/chat/chat_controller.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/firebase/database_manager.dart';
import 'package:bluebubbles/managers/firebase/fcm_manager.dart';
import 'package:bluebubbles/managers/incoming_queue.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:socket_io_client/socket_io_client.dart';

import 'managers/event_dispatcher.dart';

export 'package:bluebubbles/services/network/http_service.dart';

enum SocketState {
  CONNECTED,
  DISCONNECTED,
  ERROR,
  CONNECTING,
  FAILED,
}

class SocketManager {
  factory SocketManager() {
    return _manager;
  }

  static final SocketManager _manager = SocketManager._internal();
  static final String tag = 'Socket';

  SocketManager._internal();

  List<String> processedGUIDS = <String>[];

  SetupBloc setup = SetupBloc();
  bool isAuthingFcm = false;

  //Socket io
  io.Socket? socket;

  Map<String, AttachmentSender> attachmentSenders = {};
  Map<int, Function> socketProcesses = {};

  final Rx<SocketState> state = SocketState.DISCONNECTED.obs;

  int addSocketProcess(Function() cb) {
    int processId = Random().nextInt(10000);
    socketProcesses[processId] = cb;
    Future.delayed(Duration(milliseconds: Random().nextInt(100)), () {
      if (state.value == SocketState.DISCONNECTED || state.value == SocketState.FAILED) {
        if (SettingsManager().settings.finishedSetup.value) {
          _manager.startSocketIO();
        }
      } else if (state.value == SocketState.CONNECTED) {
        cb();
      }
    });
    return processId;
  }

  void finishSocketProcess(int? processId) {
    socketProcesses.remove(processId);
    Future.delayed(Duration(milliseconds: Random().nextInt(100)), () {
      _socketProcessUpdater.sink.add(socketProcesses.keys.toList());
    });
  }

  final StreamController<List<int>> _socketProcessUpdater = StreamController<List<int>>.broadcast();

  Stream<List<int>> get socketProcessUpdater => _socketProcessUpdater.stream;

  final StreamController<String> _attachmentSenderCompleter = StreamController<String>.broadcast();

  Stream<String> get attachmentSenderCompleter => _attachmentSenderCompleter.stream;

  void addAttachmentSender(AttachmentSender sender) {
    if (sender.guid == null) return;
    attachmentSenders[sender.guid!] = sender;
  }

  void finishSender(String attachmentGuid) {
    attachmentSenders.remove(attachmentGuid);
    _attachmentSenderCompleter.sink.add(attachmentGuid);
  }

  Map<String, Function> disconnectSubscribers = {};

  String? token;

  void socketStatusUpdate(String status, dynamic data) {
    Logger.info("Socket status update: $status", tag: tag);
    if (data != null) {
      Logger.debug("Data: ${data.toString()}", tag: tag);
    }

    switch (status) {
      case "connect":
        // Make sure we set the state value first so that listeners can show the correct
        // status as quickly as possible. This was lower before and was causing some lag
        // time between when we actually connected and when the connection dot showed that.
        state.value = SocketState.CONNECTED;

        // Once we connect, we need to make sure that we register the device with the server.
        // This is to ensure we always will be registered to receive notifications
        fcm.registerDevice();

        // Clear the errored socket notification (if any)
        NotificationManager().clearSocketWarning();

        // Remove any disconnected subscribers
        _manager.disconnectSubscribers.forEach((key, value) {
          value();
          _manager.disconnectSubscribers.remove(key);
        });
        for (Function element in _manager.socketProcesses.values) {
          element();
        }

        // Start an incremental sync
        if (SettingsManager().settings.finishedSetup.value) {
          setup.startIncrementalSync();

          if ((kIsDesktop || kIsWeb) && ContactManager().contacts.isEmpty) {
            // Get contacts whenever we connect if we didn't yet
            Future.delayed(Duration.zero, () async {
              await ContactManager().loadContacts();
              EventDispatcher().emit('refresh', null);
            });
          }
          if (kIsWeb && ChatBloc().chats.isEmpty) {
            // Get contacts whenever we connect if we didn't yet
            Future.delayed(Duration.zero, () async {
              await ChatBloc().refreshChats(force: true);
              EventDispatcher().emit('refresh', null);
            });
          }
        }

        // Make sure we have the correct macOS version loaded so that we can show UI elements accurately
        SettingsManager().getMacOSVersion(refresh: true);
        return;
      case "connect_error":
        // If we are already errored or failed, we don't need to re-set the variable
        if (state.value != SocketState.ERROR && state.value != SocketState.FAILED) {
          state.value = SocketState.ERROR;

          // After 5 seconds of an error, we should retry the connection
          Timer(Duration(seconds: 5), () {
            if (state.value != SocketState.ERROR && state.value != SocketState.FAILED) return;
            fdb.fetchNewUrl(connectToSocket: true);
          });

          // After 20 seconds, if we still aren't connected, show the warning notification
          Timer(Duration(seconds: 20), () {
            if (state.value != SocketState.ERROR && state.value != SocketState.FAILED) return;
            state.value = SocketState.FAILED;
            Logger.error("Unable to connect", tag: tag);

            // Only show the notification if setup is finished
            if (SettingsManager().settings.finishedSetup.value) {
              NotificationManager().createSocketWarningNotification();
            }

            // Clear any socket processes
            List<Function> processes = socketProcesses.values.toList();
            for (Function value in processes) {
              value(true);
            }
            socketProcesses = {};

            // If we aren't alive and we are on Android, close the socket
            if (!LifeCycleManager().isAlive && !kIsDesktop && !kIsWeb) {
              closeSocket(force: true);
            }
          });
        }
        return;
      case "disconnect":
        // If we already knew we were disconnected or failed, don't do anything
        if (state.value == SocketState.DISCONNECTED || state.value == SocketState.FAILED) return;
        state.value = SocketState.DISCONNECTED;

        for (Function f in _manager.disconnectSubscribers.values) {
          f.call();
        }

        // If we are still disconnected after 5 seconds, show the disconnected snackbar
        Timer t;
        t = Timer(const Duration(seconds: 5), () {
          if (state.value == SocketState.DISCONNECTED &&
              LifeCycleManager().isAlive &&
              !(Get.isSnackbarOpen ?? false) &&
              SettingsManager().settings.finishedSetup.value) {
            showSnackbar('Socket Disconnected', 'You are no longer connected to the socket 🔌');
          }
        });
        LifeCycleManager().stream.listen((event) {
          if (!event && t.isActive) {
            t.cancel();
          } else {
            t = Timer(const Duration(seconds: 5), () {
              if (state.value == SocketState.DISCONNECTED &&
                  LifeCycleManager().isAlive &&
                  !(Get.isSnackbarOpen ?? false)) {
                showSnackbar('Socket Disconnected', 'You are no longer connected to the socket 🔌');
              }
            });
          }
        });
        return;
      case "reconnecting":
      case "reconnect":
        Logger.info("Reconnecting to socket...");
        state.value = SocketState.CONNECTING;
        for (Function element in _manager.socketProcesses.values) {
          element.call();
        }
        return;
      default:
        return;
    }
  }

  String handleNewMessage(_data) {
    Map<String, dynamic>? data = _data;
    IncomingQueue().add(QueueItem(event: "handle-message", item: {"data": data}));
    return "";
  }

  String handleChatStatusChange(_data) {
    Map<String, dynamic>? data = _data;
    IncomingQueue().add(QueueItem(event: IncomingQueue.HANDLE_CHAT_STATUS_CHANGE, item: {"data": data}));
    return "";
  }

  void startSocketIO({bool forceNewConnection = false, bool catchException = true}) {
    //removed check for settings being null here, could be an issue later but I doubt it (tneotia)
    if ((state.value == SocketState.CONNECTING || state.value == SocketState.CONNECTED) && !forceNewConnection) {
      Logger.debug("Already connected", tag: tag);
      return;
    }
    if (state.value == SocketState.FAILED) {
      state.value = SocketState.CONNECTING;
    }

    // If we already have a socket connection, kill it
    if (_manager.socket != null) {
      _manager.socket!.destroy();
    }

    String? serverAddress = sanitizeServerAddress();
    if (serverAddress == null) {
      Logger.warn("Server Address is not yet configured. Not connecting...", tag: tag);
      return;
    }

    Logger.info("Configuring socket.io client...", tag: tag);

    try {
      // Create a new socket connection
      /*_manager.socket = SocketIOManager().createSocketIO(serverAddress, "/",
          query: "guid=${encodeUri(SettingsManager().settings.guidAuthKey)}",
          socketStatusCallback: (data) => socketStatusUpdate(data));*/
      OptionBuilder options = OptionBuilder()
          .setQuery({"guid": encodeUri(SettingsManager().settings.guidAuthKey.value)})
          .setTransports(['websocket', 'polling'])
          // Disable so that we can create the listeners first
          .disableAutoConnect()
          .enableReconnection();
      if (!SettingsManager().settings.finishedSetup.value) {
        // Necessary so that auth works after a failed attempt
        options.enableForceNewConnection();
      } else {
        options.disableForceNewConnection();
      }
      _manager.socket = io.io(serverAddress, options.build());

      if (_manager.socket == null) {
        Logger.error("Socket was never created. Can't connect to server...", tag: tag);
        return;
      }

      _manager.socket!.clearListeners();

      _manager.socket!.onConnect((data) => socketStatusUpdate("connect", data));
      _manager.socket!.onReconnect((data) => socketStatusUpdate("reconnect", data));
      _manager.socket!.onDisconnect((data) => socketStatusUpdate("disconnect", data));
      _manager.socket!.onConnectError((data) => socketStatusUpdate("connect_error", data));
      _manager.socket!.onConnectTimeout((data) => socketStatusUpdate("connect_timeout", data));
      _manager.socket!.onReconnectAttempt((data) => socketStatusUpdate("reconnect_attempt", data));
      _manager.socket!.onConnecting((data) => socketStatusUpdate("connecting", data));
      _manager.socket!.onReconnect((data) => socketStatusUpdate("reconnect", data));
      _manager.socket!.onReconnecting((data) => socketStatusUpdate("reconnecting", data));
      _manager.socket!.onError((data) => socketStatusUpdate("error", data));

      /**
       * Callback event for when the server successfully added a new FCM device
       */
      _manager.socket!.on("fcm-device-id-added", (data) {
        // TODO: Possibly turn this into a notification for the user?
        // This could act as a "pseudo" security measure so they're alerted
        // when a new device is registered
        Logger.info("FCM device added: $data", tag: tag);
      });

      /**
       * If the server sends us an error it ran into, handle it
       */
      _manager.socket!.on("error", (data) {
        Logger.info("An error occurred: $data", tag: tag);
      });

      /**
       * Handle new messages detected by the server
       */
      _manager.socket!.on("new-message", handleNewMessage);
      _manager.socket!.on("group-name-change", handleNewMessage);
      _manager.socket!.on("participant-removed", handleNewMessage);
      _manager.socket!.on("participant-added", handleNewMessage);
      _manager.socket!.on("participant-left", handleNewMessage);

      /**
       * Handle Private API features
       */
      _manager.socket!.on("chat-read-status-changed", handleChatStatusChange);
      _manager.socket!.on("typing-indicator", (_data) {
        if (!SettingsManager().settings.enablePrivateAPI.value) return;

        Map<String, dynamic> data = _data;
        ChatController? currentChat = ChatManager().getChatControllerByGuid(data["guid"]);
        if (currentChat == null) return;
        if (data["display"]) {
          currentChat.displayTypingIndicator();
        } else {
          currentChat.hideTypingIndicator();
        }
      });

      /**
       * Handle errors sent by the server
       */
      _manager.socket!.on("message-send-error", (_data) async {
        Map<String, dynamic> data = _data;
        Message message = Message.fromMap(data);

        // If there are no chats, try to find it in the DB via the message
        Chat? chat;
        if (isNullOrEmpty(data["chats"])!) {
          chat = message.getChat();
        } else {
          chat = Chat.fromMap(data['chats'][0]);
        }

        // Save the chat in-case is doesn't exist
        if (chat != null) {
          chat.save();
        }

        // Lastly, find the message
        Message msg = Message.findOne(guid: message.guid)!;

        // Check if we already have an error, and save if we don't
        if (msg.error == 0) {
          // TODO: ADD NOTIFICATION TO USER IF FAILURE
          message.save();
        }

        return Future.value("");
      });

      /**
       * When the server detects a message timeout (aka, no match found),
       * handle it by replacing the temp-guid with error-guid so we can do
       * something about it (or at least just track it)
       */
      _manager.socket!.on("message-timeout", (_data) async {
        Logger.info("Client received message timeout", tag: tag);
        Map<String, dynamic> data = _data;

        Message? message = Message.findOne(guid: data["tempGuid"]);
        if (message == null) return Future.value("");
        message.error = 1003;
        message.guid = message.guid!.replaceAll("temp", "error-Message Timeout");
        await Message.replaceMessage(data["tempGuid"], message);
        return Future.value("");
      });

      /**
       * When an updated message comes in, update it in the database.
       * This may be when a read/delivered date has been changed.
       */
      _manager.socket!.on("updated-message", (_data) async {
        IncomingQueue().add(QueueItem(event: "handle-updated-message", item: {"data": _data}));
      });

      Logger.info("Connecting to the socket at: $serverAddress");
      socketStatusUpdate("reconnecting", null);
      _manager.socket!.connect();
    } catch (e) {
      if (!catchException) {
        throw ("[$tag] -> Failed to connect: ${e.toString()}");
      } else {
        Logger.error("Failed to connect", tag: tag);
        Logger.error(e.toString(), tag: tag);
      }
    }
  }

  void closeSocket({bool force = false}) {
    if (!force && _manager.socketProcesses.isNotEmpty) {
      Logger.info("Not closing the socket! Count: ${socketProcesses.length}");
      return;
    }
    if (_manager.socket != null) {
      _manager.socket!.disconnect();
      _manager.socket!.destroy();
    }
    _manager.socket = null;
    state.value = SocketState.DISCONNECTED;
    NotificationManager().clearSocketWarning();
  }

  Future<Map<String, dynamic>> sendMessage(
      String event, Map<String, dynamic>? message, Function(Map<String, dynamic>) cb,
      {String? reason, bool awaitResponse = true}) {
    Completer<Map<String, dynamic>> completer = Completer();
    int _processId = 0;
    void socketCB([bool finishWithError = false]) {
      if (finishWithError) {
        cb({
          'status': MessageError.NO_CONNECTION,
          'error': {'message': 'Failed to Connect'}
        });
        completer.complete({
          'status': MessageError.NO_CONNECTION,
          'error': {'message': 'Failed to Connect'}
        });
        if (awaitResponse) _manager.finishSocketProcess(_processId);
      } else {
        _manager.socket?.emitWithAck(event, message, ack: (response) {
          if (response.containsKey('encrypted') && response['encrypted']) {
            try {
              response['data'] =
                  jsonDecode(decryptAESCryptoJS(response['data'], SettingsManager().settings.guidAuthKey.value));
            } catch (ex) {
              response['data'] = decryptAESCryptoJS(response['data'], SettingsManager().settings.guidAuthKey.value);
            }
          }

          cb(response);
          if (!completer.isCompleted) {
            completer.complete(response);
          }

          if (awaitResponse) _manager.finishSocketProcess(_processId);
        });
      }
    }

    if (awaitResponse) {
      _processId = _manager.addSocketProcess(socketCB);
    } else {
      socketCB();
    }
    if (reason != null) Logger.info("Added process with id $_processId because $reason");

    return completer.future;
  }

  void toggleSetupFinished(bool isFinished, {bool applyToDb = true}) {
    if (SettingsManager().settings.finishedSetup.value != isFinished) {
      SettingsManager().settings.finishedSetup.value = isFinished;
      SettingsManager().saveSettings(SettingsManager().settings);
    }
  }

  dispose() {
    _attachmentSenderCompleter.close();
    _socketProcessUpdater.close();
  }
}
