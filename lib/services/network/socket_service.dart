import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/utils/crypto_utils.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart';

SocketService socket = Get.isRegistered<SocketService>() ? Get.find<SocketService>() : Get.put(SocketService());

enum SocketState {
  connected,
  disconnected,
  error,
  connecting,
}

class SocketService extends GetxService {
  final Rx<SocketState> state = SocketState.disconnected.obs;
  SocketState _lastState = SocketState.disconnected;
  RxString lastError = "".obs;
  Timer? _reconnectTimer;
  late Socket socket;
  
  String get serverAddress => http.origin;
  String get password => ss.settings.guidAuthKey.value;

  @override
  void onInit() {
    super.onInit();
    startSocket();
    Connectivity().onConnectivityChanged.listen((event) {
      if (event != ConnectivityResult.wifi && http.originOverride != null) {
        Logger.info("Detected switch off wifi, removing localhost address...");
        http.originOverride = null;
      }
    });
  }

  @override
  void onClose() {
    closeSocket();
    super.onClose();
  }
  
  void startSocket() {
    OptionBuilder options = OptionBuilder()
        .setQuery({"guid": encodeUri(password)})
        .setTransports(['websocket', 'polling'])
        .setExtraHeaders(ss.settings.customHeaders)
        // Disable so that we can create the listeners first
        .disableAutoConnect()
        .enableReconnection();
    socket = io(serverAddress, options.build());
    // placed here so that [socket] is still initialized
    if (isNullOrEmpty(serverAddress)!) return;

    socket.onConnect((data) => handleStatusUpdate(SocketState.connected, data));
    socket.onReconnect((data) => handleStatusUpdate(SocketState.connected, data));
    
    socket.onReconnectAttempt((data) => handleStatusUpdate(SocketState.connecting, data));
    socket.onReconnecting((data) => handleStatusUpdate(SocketState.connecting, data));
    socket.onConnecting((data) => handleStatusUpdate(SocketState.connecting, data));
    
    socket.onDisconnect((data) => handleStatusUpdate(SocketState.disconnected, data));
    
    socket.onConnectError((data) => handleStatusUpdate(SocketState.error, data));
    socket.onConnectTimeout((data) => handleStatusUpdate(SocketState.error, data));
    socket.onError((data) => handleStatusUpdate(SocketState.error, data));

    // custom events
    // only listen to these events from socket on web/desktop (FCM handles on Android)
    if (kIsWeb || kIsDesktop || ss.settings.keepAppAlive.value) {
      socket.on("group-name-change", (data) => handleCustomEvent("group-name-change", data));
      socket.on("participant-removed", (data) => handleCustomEvent("participant-removed", data));
      socket.on("participant-added", (data) => handleCustomEvent("participant-added", data));
      socket.on("participant-left", (data) => handleCustomEvent("participant-left", data));
    }
    socket.on("new-message", (data) => handleCustomEvent("new-message", data));
    socket.on("updated-message", (data) => handleCustomEvent("updated-message", data));
    socket.on("typing-indicator", (data) => handleCustomEvent("typing-indicator", data));
    socket.on("chat-read-status-changed", (data) => handleCustomEvent("chat-read-status-changed", data));

    socket.connect();
  }

  void disconnect() {
    if (isNullOrEmpty(serverAddress)!) return;
    socket.disconnect();
    state.value = SocketState.disconnected;
  }

  void reconnect() {
    if (isNullOrEmpty(serverAddress)!) return;
    state.value = SocketState.connecting;
    socket.connect();
  }

  void closeSocket() {
    if (isNullOrEmpty(serverAddress)!) return;
    socket.dispose();
    state.value = SocketState.disconnected;
  }

  void restartSocket() {
    closeSocket();
    startSocket();
  }

  void forgetConnection() {
    closeSocket();
    ss.settings.guidAuthKey.value = "";
    ss.settings.serverAddress.value = "";
    ss.saveSettings();
  }

  Future<Map<String, dynamic>> sendMessage(String event, Map<String, dynamic> message) {
    Completer<Map<String, dynamic>> completer = Completer();

    socket.emitWithAck(event, message, ack: (response) {
      if (response['encrypted'] == true) {
        response['data'] = jsonDecode(decryptAESCryptoJS(response['data'], password));
      }

      if (!completer.isCompleted) {
        completer.complete(response);
      }
    });

    return completer.future;
  }

  void handleStatusUpdate(SocketState status, dynamic data) {
    if (_lastState == status) return;
    _lastState = status;

    switch (status) {
      case SocketState.connected:
        state.value = SocketState.connected;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        NetworkTasks.onConnect();
        return;
      case SocketState.disconnected:
        Logger.info("Disconnected from socket...");
        state.value = SocketState.disconnected;
        return;
      case SocketState.connecting:
        Logger.info("Connecting to socket...");
        state.value = SocketState.connecting;
        return;
      case SocketState.error:
        Logger.info("Socket connect error, fetching new URL...");
        
        if (data is SocketException) {
          handleSocketException(data);
        }

        state.value = SocketState.error;
        // After 5 seconds of an error, we should retry the connection
        _reconnectTimer = Timer(const Duration(seconds: 5), () async {
          if (state.value == SocketState.connected) return;

          await fdb.fetchNewUrl();
          restartSocket();
        });
        return;
      default:
        return;
    }
  }

  void handleSocketException(SocketException e) {
    String msg = e.message;
    if (msg.contains("Failed host lookup")) {
      lastError.value = "Failed to resolve hostname";
    } else {
      lastError.value = msg;
    }
  }

  void handleCustomEvent(String event, Map<String, dynamic> data) async {
    Logger.info("Received $event from socket");
    switch (event) {
      case "new-message":
        if (!isNullOrEmpty(data)!) {
          final payload = ServerPayload.fromJson(data);
          final message = Message.fromMap(payload.data);
          if (message.isFromMe!) {
            if (payload.data['tempGuid'] == null) {
              ah.outOfOrderTempGuids.add(message.guid!);
              await Future.delayed(const Duration(milliseconds: 500));
              if (!ah.outOfOrderTempGuids.contains(message.guid!)) return;
            } else {
              ah.outOfOrderTempGuids.remove(message.guid!);
            }
          }
          inq.queue(IncomingItem.fromMap(QueueType.newMessage, payload.data));
        }
        return;
      case "updated-message":
        if (!isNullOrEmpty(data)!) {
          final payload = ServerPayload.fromJson(data);
          inq.queue(IncomingItem.fromMap(QueueType.updatedMessage, payload.data));
        }
        return;
      case "group-name-change":
      case "participant-removed":
      case "participant-added":
      case "participant-left":
        try {
          final item = IncomingItem.fromMap(QueueType.updatedMessage, data);
          ah.handleNewOrUpdatedChat(item.chat);
        } catch (_) {}
        return;
      case "chat-read-status-changed":
        Chat? chat = Chat.findOne(guid: data["chatGuid"]);
        if (chat != null && (data["read"] == true || data["read"] == false)) {
          chat.toggleHasUnread(!data["read"]!, privateMark: false);
        }
        return;
      case "typing-indicator":
        final chat = chats.chats.firstWhereOrNull((element) => element.guid == data["guid"]);
        if (chat != null) {
          final controller = cvc(chat);
          controller.showTypingIndicator.value = data["display"];
        }
        return;
      default:
        return;
    }
  }
}