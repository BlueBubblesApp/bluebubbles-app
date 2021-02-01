import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/helpers/crypto.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/attachment_info_bloc.dart';
import 'package:bluebubbles/managers/current_chat.dart';
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

  Future<void> removeChatNotification(Chat chat) async {
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
              isIncremental: true, onConnectionError: (String err) {
            debugPrint(
                "(SYNC) Error performing incremental sync. Not saving last sync date.");
            debugPrint(err);
          });
        return;
      case "connect_error":
        debugPrint("CONNECT ERROR");
        if (state != SocketState.ERROR && state != SocketState.FAILED) {
          state = SocketState.ERROR;
          Timer(Duration(seconds: 5), () {
            if (state != SocketState.ERROR) return;
            refreshConnection(connectToSocket: true);
          });
          Timer(Duration(seconds: 20), () {
            if (state != SocketState.ERROR) return;
            debugPrint("UNABLE TO CONNECT");

            // Only show the notification if setup is finished
            if (SettingsManager().settings.finishedSetup) {
              NotificationManager().createSocketWarningNotification();
            }

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
    if (!SettingsManager().settings.enablePrivateAPI)
      return new Future.value("");

    Map<String, dynamic> data = jsonDecode(_data);
    IncomingQueue().add(new QueueItem(
        event: IncomingQueue.HANDLE_CHAT_STATUS_CHANGE, item: {"data": data}));
    return new Future.value("");
  }

  Future<void> startSocketIO(
      {bool forceNewConnection = false, bool catchException = true}) async {
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

    String serverAddress = getServerAddress();
    if (serverAddress == null) {
      debugPrint("Server Address is not yet configured. Not connecting...");
      return;
    }

    debugPrint("Starting socket io with the server: $serverAddress");

    try {
      // Create a new socket connection
      _manager.socket = SocketIOManager().createSocketIO(serverAddress, "/",
          query:
              "guid=${Uri.encodeFull(SettingsManager().settings.guidAuthKey)}",
          socketStatusCallback: (data) => socketStatusUpdate(data));

      if (_manager.socket == null) {
        debugPrint("Socket was never created. Can't connect to server...");
        return;
      }

      await _manager.socket.init();
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
       * Handle Private API features
       */
      _manager.socket
          .subscribe("chat-read-status-changed", handleChatStatusChange);
      _manager.socket.subscribe("typing-indicator", (_data) {
        if (!SettingsManager().settings.enablePrivateAPI) return;

        Map<String, dynamic> data = jsonDecode(_data);
        CurrentChat currentChat =
            AttachmentInfoBloc().getCurrentChat(data["guid"]);
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
      _manager.socket.subscribe("message-send-error", (_data) async {
        Map<String, dynamic> data = jsonDecode(_data);
        Message message = Message.fromMap(data);

        // If there are no chats, try to find it in the DB via the message
        Chat chat;
        if (isNullOrEmpty(data["chats"])) {
          chat = await Message.getChat(message);
        } else {
          chat = Chat.fromMap(data['chats'][0]);
        }

        // Save the chat in-case is doesn't exist
        if (chat != null) {
          await chat.save();
        }

        // Lastly, find the message
        Message msg = await Message.findOne({'guid': message.guid});

        // Check if we already have an error, and save if we don't
        if (msg.error == 0) {
          // TODO: ADD NOTIFICATION TO USER IF FAILURE
          await message.save();
        }

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
        if (message == null) return new Future.value("");
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
      if (!catchException) {
        throw (("(SocketManager) -> ") + e.toString());
      } else {
        debugPrint("FAILED TO CONNECT");
      }
    }
  }

  void closeSocket({bool force = false}) {
    if (!force && _manager.socketProcesses.length != 0) {
      debugPrint("won't close " + socketProcesses.length.toString());
      return;
    }
    if (_manager.socket != null) {
      _manager.socket.disconnect();
      _manager.socket.destroy();
    }
    _manager.socket = null;
    state = SocketState.DISCONNECTED;
    NotificationManager().clearSocketWarning();
  }

  Future<void> authFCM({bool catchException = true, bool force = false}) async {
    if (SettingsManager().fcmData.isNull) {
      debugPrint("No FCM Auth data found. Skipping FCM authentication");
      return;
    } else if (token != null && !force) {
      debugPrint("already authorized fcm " + token);
      if (_manager.socket != null) {
        String deviceName = await getDeviceName();
        _manager.sendMessage("add-fcm-device",
            {"deviceId": token, "deviceName": deviceName}, (data) {},
            reason: "authfcm", awaitResponse: false);
      }
      return;
    }

    try {
      final String result = await MethodChannelInterface()
          .invokeMethod('auth', SettingsManager().fcmData.toMap());
      token = result;
      if (_manager.socket != null) {
        String deviceName = await getDeviceName();
        _manager.sendMessage("add-fcm-device",
            {"deviceId": token, "deviceName": deviceName}, (data) {},
            reason: "authfcm", awaitResponse: false);
        debugPrint(token);
      }
    } on PlatformException catch (e) {
      if (!catchException) {
        throw ("(AuthFCM) -> " + e.toString());
      } else {
        token = "Failed to get token: " + e.toString();
        debugPrint(token);
      }
    }
  }

  Future<List<dynamic>> getAttachments(String chatGuid, String messageGuid,
      {Function(List<dynamic>) cb}) {
    Completer<List<dynamic>> completer = new Completer();

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

      List<dynamic> output = [];
      if (json.containsKey("data") && json["data"].length > 0) {
        output = json["data"];
      }

      completer.complete(output);

      if (cb != null) cb(output);
    });

    return completer.future;
  }

  Future<List<dynamic>> loadMessageChunk(Chat chat, int offset,
      {limit = 25}) async {
    Completer<List<dynamic>> completer = new Completer();

    Map<String, dynamic> params = Map();
    params["identifier"] = chat.guid;
    params["limit"] = limit;
    params["offset"] = offset;
    params["withBlurhash"] = false;
    params["where"] = [
      {"statement": "message.service = 'iMessage'", "args": null}
    ];

    SocketManager().sendMessage("get-chat-messages", params, (data) async {
      if (data['status'] != 200) {
        completer.completeError(data['error']);
      }

      completer.complete(data["data"]);
    });

    return completer.future;
  }

  Future<Chat> fetchChat(String chatGuid, {withParticipants = true}) async {
    Completer<Chat> completer = new Completer();
    debugPrint("(Fetch Chat) Fetching full chat metadata from server.");

    Map<String, dynamic> params = Map();
    params["chatGuid"] = chatGuid;
    params["withParticipants"] = withParticipants;
    SocketManager().sendMessage("get-chat", params, (data) async {
      if (data['status'] != 200) {
        return completer.completeError(new Exception(data['error']['message']));
      }

      Map<String, dynamic> chatData = data["data"];
      if (chatData == null) {
        debugPrint("(Fetch Chat) Server returned no metadata for chat.");
        return completer.complete(null);
      }

      debugPrint("(Fetch Chat) Got updated chat metadata from server. Saving.");
      Chat newChat = Chat.fromMap(chatData);

      // Resave the chat after we've got the participants
      await newChat.save();
      completer.complete(newChat);
    });

    return completer.future;
  }

  Future<List<dynamic>> fetchMessages(Chat chat,
      {int offset: 0,
      int limit: 100,
      int after,
      bool onlyAttachments: false,
      List<Map<String, dynamic>> where: const []}) async {
    Completer<List<dynamic>> completer = new Completer();
    debugPrint("(Fetch Messages) Fetching data.");

    Map<String, dynamic> params = Map();
    params["chatGuid"] = chat?.guid;
    params["offset"] = offset;
    params["limit"] = limit;
    params["withAttachments"] = true;
    params["withHandle"] = true;
    params["sort"] = "DESC";
    params["where"] = where;

    if (after != null) {
      params["after"] = after;
    }

    if (onlyAttachments) {
      params["where"].add({
        "statement": "message.cache_has_attachments = :flag",
        "args": {"flag": 1}
      });
    }

    SocketManager().sendMessage("get-messages", params, (data) async {
      if (data['status'] != 200) {
        return completer.completeError(new Exception(data['error']['message']));
      }

      List<dynamic> messageData = data["data"];
      if (messageData == null) {
        debugPrint("(Fetch Messages) Server returned no messages.");
        return completer.complete(null);
      }

      debugPrint("(Fetch Messages) Got ${messageData.length} messages");
      completer.complete(messageData);
    });

    return completer.future;
  }

  Future<Map<String, dynamic>> sendMessage(String event,
      Map<String, dynamic> message, Function(Map<String, dynamic>) cb,
      {String reason, bool awaitResponse = true, String path}) {
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
        if (path == null) {
          _manager.socket.sendMessage(event, jsonEncode(message),
              (String data) {
            Map<String, dynamic> response = jsonDecode(data);
            if (response.containsKey('encrypted') && response['encrypted']) {
              try {
                response['data'] = jsonDecode(decryptAESCryptoJS(
                    response['data'], SettingsManager().settings.guidAuthKey));
              } catch (ex) {
                response['data'] = decryptAESCryptoJS(
                    response['data'], SettingsManager().settings.guidAuthKey);
              }
            }

            cb(response);
            completer.complete(response);
            if (awaitResponse) _manager.finishSocketProcess(_processId);
          });
        } else {
          _manager.socket.sendMessageWithoutReturn(event, jsonEncode(message),
              path, SettingsManager().settings.guidAuthKey, (String data) {
            debugPrint(data);
            Map<String, dynamic> response = jsonDecode(data);
            cb(response);
            completer.complete(response);
            if (awaitResponse) _manager.finishSocketProcess(_processId);
          });
        }
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
    settingsCopy.serverAddress = getServerAddress(address: serverAddress);

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

    if (MethodChannelInterface() == null) {
      debugPrint(
          "Method channel interface is null, not refreshing connection...");
      return;
    }

    // Get the server URL
    try {
      String url =
          await MethodChannelInterface().invokeMethod("get-server-url");
      url = getServerAddress(address: url);

      debugPrint("New server URL: $url");

      // Set the server URL
      Settings _settingsCopy = SettingsManager().settings;
      if (_settingsCopy.serverAddress == url) return;
      _settingsCopy.serverAddress = url;
      await SettingsManager().saveSettings(_settingsCopy);
      if (connectToSocket) {
        startSocketIO(forceNewConnection: connectToSocket);
      }
    } catch (e) {}
  }
}
