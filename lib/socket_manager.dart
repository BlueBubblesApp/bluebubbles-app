import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/incoming_queue.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter_socket_io/socket_io_manager.dart';
import 'package:flutter_socket_io/flutter_socket_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'helpers/attachment_sender.dart';
import 'managers/method_channel_interface.dart';
import 'repository/models/message.dart';
import './repository/models/chat.dart';

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

  SocketManager._internal();

  void removeChatNotification(Chat chat) async {
    await chat.setUnreadStatus(false);
    ChatBloc().updateChat(chat);
  }

  List<String> processedGUIDS = <String>[];

  SetupBloc setup = new SetupBloc();
  StreamController<bool> finishedSetup = StreamController<bool>();

  //Socket io
  SocketIO socket;

  Map<String, AttachmentDownloader> attachmentDownloaders = Map();
  Map<String, AttachmentSender> attachmentSenders = Map();
  Map<int, Function> socketProcesses = new Map();

  SocketState _state = SocketState.DISCONNECTED;

  StreamController<SocketState> _connectionStateStream =
      StreamController<SocketState>.broadcast();

  Stream<SocketState> get connectionStateStream =>
      _connectionStateStream.stream;

  SocketState get state => _state;

  set state(SocketState val) {
    _state = val;
    _connectionStateStream.sink.add(_state);
  }

  int addSocketProcess(Function() cb) {
    int processId = Random().nextInt(10000);
    socketProcesses[processId] = cb;
    Future.delayed(Duration(milliseconds: Random().nextInt(100)), () {
      if (state == SocketState.DISCONNECTED || state == SocketState.FAILED) {
        _manager.startSocketIO();
      } else if (state == SocketState.CONNECTED) {
        cb();
      }
    });
    return processId;
  }

  void finishSocketProcess(int processId) {
    socketProcesses.remove(processId);
    Future.delayed(Duration(milliseconds: Random().nextInt(100)), () {
      _socketProcessUpdater.sink.add(socketProcesses.keys.toList());
    });
  }

  StreamController _socketProcessUpdater =
      StreamController<List<int>>.broadcast();

  Stream<List<int>> get socketProcessUpdater => _socketProcessUpdater.stream;

  StreamController _attachmentSenderCompleter =
      StreamController<String>.broadcast();
  Stream<String> get attachmentSenderCompleter =>
      _attachmentSenderCompleter.stream;

  void addAttachmentDownloader(String guid, AttachmentDownloader downloader) {
    attachmentDownloaders[guid] = downloader;
  }

  void addAttachmentSender(AttachmentSender sender) {
    attachmentSenders[sender.guid] = sender;
  }

  void finishDownloader(String guid) {
    attachmentDownloaders.remove(guid);
  }

  void finishSender(String attachmentGuid) {
    attachmentSenders.remove(attachmentGuid);
    _attachmentSenderCompleter.sink.add(attachmentGuid);
  }

  Map<String, Function> disconnectSubscribers = new Map();

  String token;

  void disconnectCallback(Function cb, String guid) {
    _manager.disconnectSubscribers[guid] = cb;
  }

  void unSubscribeDisconnectCallback(String guid) {
    _manager.disconnectSubscribers.remove(guid);
  }

  void socketStatusUpdate(data) {
    switch (data) {
      case "connect":
        authFCM();
        NotificationManager().clearSocketWarning();
        _manager.disconnectSubscribers.forEach((key, value) {
          value();
          _manager.disconnectSubscribers.remove(key);
        });

        state = SocketState.CONNECTED;
        _manager.socketProcesses.values.forEach((element) {
          element();
        });
        if (SettingsManager().settings.finishedSetup)
          setup.startIncrementalSync(SettingsManager().settings,
              onConnectionError: (String err) {
            debugPrint(
                "(SYNC) Error performing incremental sync. Not saving last sync date.");
            debugPrint(err);
          });
        return;
      case "connect_error":
        debugPrint("CONNECT ERROR");
        if (state != SocketState.ERROR && state != SocketState.FAILED) {
          state = SocketState.ERROR;
          Timer(Duration(seconds: 10), () {
            if (state != SocketState.ERROR) return;
            debugPrint("UNABLE TO CONNECT");
            NotificationManager().createSocketWarningNotification();
            state = SocketState.FAILED;
            List processes = socketProcesses.values.toList();
            processes.forEach((value) {
              value(true);
            });
            socketProcesses = new Map();
            if (!LifeCycleManager().isAlive) {
              closeSocket(force: true);
            }
          });
        }
        return;
      case "disconnect":
        if (state == SocketState.FAILED) return;
        _manager.disconnectSubscribers.values.forEach((f) {
          f();
        });
        debugPrint("disconnected");
        state = SocketState.DISCONNECTED;

        EventDispatcher()
            .emit("show-snackbar", {"text": "Disconnected from socket! 🔌"});
        return;
      case "reconnect":
        debugPrint("RECONNECTED");
        state = SocketState.CONNECTING;
        _manager.socketProcesses.values.forEach((element) {
          element();
        });
        return;
      default:
        return;
    }
  }

  Future<String> handleNewMessage(_data) async {
    Map<String, dynamic> data = jsonDecode(_data);
    IncomingQueue()
        .add(new QueueItem(event: "handle-message", item: {"data": data}));
    return new Future.value("");
  }

  Future<String> handleChatStatusChange(_data) async {
    Map<String, dynamic> data = jsonDecode(_data);
    IncomingQueue().add(new QueueItem(
        event: IncomingQueue.HANDLE_CHAT_STATUS_CHANGE, item: {"data": data}));
    return new Future.value("");
  }

  startSocketIO({bool forceNewConnection = false}) async {
    if (SettingsManager().settings == null) {
      debugPrint("Settings have not loaded yet, not starting socket...");
      return;
    }

    if ((state == SocketState.CONNECTING || state == SocketState.CONNECTED) &&
        !forceNewConnection) {
      debugPrint("already connected");
      return;
    }
    if (state == SocketState.FAILED) {
      state = SocketState.CONNECTING;
    }

    // If we already have a socket connection, kill it
    if (_manager.socket != null) {
      _manager.socket.destroy();
    }

    debugPrint(
        "Starting socket io with the server: ${SettingsManager().settings.serverAddress}");

    try {
      // Create a new socket connection
      _manager.socket = SocketIOManager().createSocketIO(
          SettingsManager().settings.serverAddress, "/",
          query: "guid=${SettingsManager().settings.guidAuthKey}",
          socketStatusCallback: (data) => socketStatusUpdate(data));

      if (_manager.socket == null) {
        debugPrint("Socket was never created. Can't connect to server...");
        return;
      }

      _manager.socket.init();
      _manager.socket.connect();
      _manager.socket.unSubscribesAll();

      /**
       * Callback event for when the server successfully added a new FCM device
       */
      _manager.socket.subscribe("fcm-device-id-added", (data) {
        // TODO: Possibly turn this into a notification for the user?
        // This could act as a "pseudo" security measure so they're alerted
        // when a new device is registered
        debugPrint("fcm device added: " + data.toString());
      });

      /**
       * If the server sends us an error it ran into, handle it
       */
      _manager.socket.subscribe("error", (data) {
        debugPrint("An error occurred: " + data.toString());
      });

      /**
       * Handle new messages detected by the server
       */
      _manager.socket.subscribe("new-message", handleNewMessage);
      _manager.socket.subscribe("group-name-change", handleNewMessage);
      _manager.socket.subscribe("participant-removed", handleNewMessage);
      _manager.socket.subscribe("participant-added", handleNewMessage);
      _manager.socket.subscribe("participant-left", handleNewMessage);
      _manager.socket
          .subscribe("chat-read-status-changed", handleChatStatusChange);

      /**
       * Handle errors sent by the server
       */
      _manager.socket.subscribe("message-send-error", (_data) async {
        Map<String, dynamic> data = jsonDecode(_data);
        Message message = Message.fromMap(data);

        // If there are no chats, try to find it in the DB via the message
        Chat chat;
        if (data["chats"].length == 0) {
          chat = await Message.getChat(message);
        } else {
          chat = Chat.fromMap(data['chats'][0]);
        }

        // Save the chat in-case is doesn't exist
        if (chat != null) {
          await chat.save();
        }

        // Lastly, save the message
        await message.save();
        return new Future.value("");
      });

      /**
       * When the server detects a message timeout (aka, no match found),
       * handle it by replacing the temp-guid with error-guid so we can do
       * something about it (or at least just track it)
       */
      _manager.socket.subscribe("message-timeout", (_data) async {
        debugPrint("Client received message timeout");
        Map<String, dynamic> data = jsonDecode(_data);

        Message message = await Message.findOne({"guid": data["tempGuid"]});
        message.error = 1003;
        message.guid = message.guid.replaceAll("temp", "error-Message Timeout");
        await Message.replaceMessage(data["tempGuid"], message);
        return new Future.value("");
      });

      /**
       * When an updated message comes in, update it in the database.
       * This may be when a read/delivered date has been changed.
       */
      _manager.socket.subscribe("updated-message", (_data) async {
        IncomingQueue().add(new QueueItem(
            event: "handle-updated-message",
            item: {"data": jsonDecode(_data)}));
      });
    } catch (e) {
      debugPrint("FAILED TO CONNECT");
    }
  }

  void closeSocket({bool force = false}) {
    if (!force && _manager.socketProcesses.length != 0) {
      debugPrint("won't close " + socketProcesses.toString());
      return;
    }
    if (_manager.socket != null) {
      _manager.socket.disconnect();
      _manager.socket.destroy();
    }
    _manager.socket = null;
    state = SocketState.DISCONNECTED;
  }

  Future<void> authFCM() async {
    if (SettingsManager().fcmData.isNull) {
      debugPrint("No FCM Auth data found. Skipping FCM authentication");
      return;
    } else if (token != null) {
      debugPrint("already authorized fcm " + token);
      if (_manager.socket != null) {
        _manager.sendMessage("add-fcm-device",
            {"deviceId": token, "deviceName": "android-client"}, (data) {},
            reason: "authfcm", awaitResponse: false);
      }
      return;
    }

    try {
      final String result = await MethodChannelInterface()
          .invokeMethod('auth', SettingsManager().fcmData.toMap());
      token = result;
      if (_manager.socket != null) {
        _manager.sendMessage("add-fcm-device",
            {"deviceId": token, "deviceName": "android-client"}, (data) {},
            reason: "authfcm", awaitResponse: false);
        debugPrint(token);
      }
    } on PlatformException catch (e) {
      token = "Failed to get token: " + e.toString();
      debugPrint(token);
    }
  }

  Future<void> getAttachments(String chatGuid, String messageGuid,
      {Function cb}) {
    Completer<void> completer = new Completer();

    dynamic params = {
      'after': 1,
      'identifier': chatGuid,
      'limit': 1,
      'withAttachments': true,
      'withChats': true,
      'where': [
        {
          'statement': 'message.guid = :guid',
          'args': {'guid': messageGuid}
        }
      ]
    };

    _manager.socket.sendMessage("get-messages", jsonEncode(params),
        (String data) async {
      dynamic json = jsonDecode(data);
      if (json["status"] != 200) return completer.completeError(json);

      if (json.containsKey("data") && json["data"].length > 0) {
        print("NUM");
        print(json["data"][0]["attachments"].length);
        await ActionHandler.handleMessage(json["data"][0], forceProcess: true);
      }

      completer.complete();

      if (cb != null) cb(json);
    });

    return completer.future;
  }

  Future<Map<String, dynamic>> sendMessage(String event,
      Map<String, dynamic> message, Function(Map<String, dynamic>) cb,
      {String reason, bool awaitResponse = true}) {
    Completer<Map<String, dynamic>> completer = Completer();
    int _processId = 0;
    Function socketCB = ([bool finishWithError = false]) {
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
        _manager.socket.sendMessage(event, jsonEncode(message), (String data) {
          cb(jsonDecode(data));
          completer.complete(jsonDecode(data));
          if (awaitResponse) _manager.finishSocketProcess(_processId);
        });
      }
    };

    if (awaitResponse) {
      _processId = _manager.addSocketProcess(socketCB);
    } else {
      socketCB();
    }
    if (reason != null)
      debugPrint("added process with id " +
          _processId.toString() +
          " because $reason");

    return completer.future;
  }

  void finishSetup() {
    finishedSetup.sink.add(true);
    ChatBloc().refreshChats();
    // notify();
  }

  /// Updates and saves a new server address and then forces a new reconnection to the socket with this address
  ///
  /// @param [serverAddress] is the new address to update to
  Future<void> newServer(String serverAddress) async {
    // We copy the settings to a local variable
    Settings settingsCopy = SettingsManager().settings;
    // Update the address of the copied settings
    settingsCopy.serverAddress = serverAddress;

    // And then save to disk
    // NOTE: we do not automatically connect to the socket or authorize fcm,
    //       because we need to do that manually with a forced connection
    await SettingsManager().saveSettings(settingsCopy);

    // Then we connect to the socket.
    // We force a connection because the socket may still be attempting to connect to the socket,
    // in which case it won't attempt to connect again.
    // We need to override this behavior.
    SocketManager().startSocketIO(forceNewConnection: true);
  }

  dispose() {
    _attachmentSenderCompleter.close();
    _connectionStateStream.close();
    _socketProcessUpdater.close();
    finishedSetup.close();
  }

  Future<void> refreshConnection({bool connectToSocket = true}) async {
    debugPrint("Fetching new server URL from Firebase");

    // Get the server URL
    String url = await MethodChannelInterface().invokeMethod("get-server-url");
    debugPrint("New server URL: $url");

    // Set the server URL
    Settings _settingsCopy = SettingsManager().settings;
    if (_settingsCopy.serverAddress == url) return;
    _settingsCopy.serverAddress = url;
    await SettingsManager().saveSettings(_settingsCopy);
    if (connectToSocket) {
      startSocketIO(forceNewConnection: connectToSocket);
    }
  }
}
