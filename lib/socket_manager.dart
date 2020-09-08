import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/managers/incoming_queue.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/queue_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:flutter_socket_io/socket_io_manager.dart';
import 'package:flutter_socket_io/flutter_socket_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'helpers/attachment_sender.dart';
import 'managers/method_channel_interface.dart';
import 'repository/models/attachment.dart';
import 'repository/models/message.dart';
import './repository/models/chat.dart';
import './repository/models/handle.dart';

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
    await chat.markReadUnread(false);
    await ChatBloc().updateChatPosition(chat);
  }

  List<String> processedGUIDS = <String>[];

  SetupBloc setup = new SetupBloc();
  StreamController<bool> finishedSetup = StreamController<bool>();

  //Socket io
  // SocketIOManager manager;
  SocketIO socket;

  //setstate for these widgets
  Map<String, Function> subscribers = new Map();

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
    // _socketProcessUpdater.sink.add(socketProcesses.keys.toList());
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

  // void removeFromSocketProcess(int processId) {
  //   socketProcesses.remove(processId);
  //   _socketProcessUpdater.sink.add(socketProcesses);
  //   // if (!LifeCycleManager().isAlive) {
  //   //   closeSocket();
  //   // }
  // }

  StreamController _socketProcessUpdater =
      StreamController<List<int>>.broadcast();

  Stream<List<int>> get socketProcessUpdater => _socketProcessUpdater.stream;

  StreamController _attachmentSenderCompleter =
      StreamController<String>.broadcast();
  Stream<String> get attachmentSenderCompleter =>
      _attachmentSenderCompleter.stream;

  // Function connectCb;
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
        // syncChats();
        // if (connectCB != null) {
        // }
        _manager.disconnectSubscribers.forEach((key, value) {
          value();
          _manager.disconnectSubscribers.remove(key);
        });

        state = SocketState.CONNECTED;
        _manager.socketProcesses.values.forEach((element) {
          element();
        });
        if (SettingsManager().settings.finishedSetup)
          setup.startIncrementalSync(SettingsManager().settings, (String err) {
            debugPrint(
                "(SYNC) Error performing incremental sync. Not saving last sync date.");
            debugPrint(err);
          });
        return;
      case "connect_error":
        debugPrint("CONNECT ERROR");
        if (state != SocketState.ERROR && state != SocketState.FAILED) {
          state = SocketState.ERROR;
          // startSocketIO();
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
            // socket.destroy();
            // NotificationManager().createNotificationChannel();
            // NotificationManager().createNewNotification(
            //     "Unable To Connect To Server",
            //     "We were unable to connect to your server, are you online?",
            //     "Socket_io",
            //     404,
            //     404);
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

  Future<void> deleteDB() async {
    Database db = await DBProvider.db.database;

    // Remove base tables
    await Handle.flush();
    await Chat.flush();
    await Attachment.flush();
    await Message.flush();

    // Remove join tables
    await db.execute("DELETE FROM chat_handle_join");
    await db.execute("DELETE FROM chat_message_join");
    await db.execute("DELETE FROM attachment_message_join");

    // Recreate tables
    DBProvider.db.buildDatabase(db);
  }

  Future<String> handleNewMessage(_data) async {
    Map<String, dynamic> data = jsonDecode(_data);
    IncomingQueue()
        .add(new QueueItem(event: "handle-message", item: {"data": data}));
    return new Future.value("");
  }

  startSocketIO({bool forceNewConnection = false}) async {
    if ((state == SocketState.CONNECTING || state == SocketState.CONNECTED) &&
        !forceNewConnection) {
      debugPrint("already connected");
      return;
    }
    if (state == SocketState.FAILED) {
      state = SocketState.CONNECTING;
    }

    // if ((state == SocketState.FAILED && socketProcesses.length > 0) &&
    //     !forceNewConnection) {
    //   debugPrint(
    //       "not reconnecting with socket processes still active and connection failed");
    //   return;
    // } else {
    //   state = SocketState.CONNECTING;
    // }

    // If we already have a socket connection, kill it
    if (_manager.socket != null) {
      _manager.socket.destroy();
    }

    debugPrint(
        "Starting socket io with the server: ${SettingsManager().settings?.serverAddress}");

    try {
      // Create a new socket connection
      _manager.socket = SocketIOManager().createSocketIO(
          SettingsManager().settings.serverAddress, "/",
          query: "guid=${SettingsManager().settings.guidAuthKey}",
          socketStatusCallback: (data) => socketStatusUpdate(data));
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
    if (SettingsManager().settings.fcmAuthData == null) {
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
          .invokeMethod('auth', SettingsManager().settings.fcmAuthData);
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
          if (reason != null)
            debugPrint("finished process with id " +
                _processId.toString() +
                " because $reason");
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

  dispose() {
    _attachmentSenderCompleter.close();
    _connectionStateStream.close();
    _socketProcessUpdater.close();
    finishedSetup.close();
  }
}
