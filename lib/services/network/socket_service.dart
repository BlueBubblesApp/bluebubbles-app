import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/helpers/crypto.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/network/network_tasks.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/core/managers/chat/chat_controller.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/services/services.dart';
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
  late final Socket socket;
  
  String? get serverAddress => ss.settings.serverAddress.value;
  String get password => ss.settings.guidAuthKey.value;

  @override
  void onInit() {
    super.onInit();
    startSocket();    
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
        // Disable so that we can create the listeners first
        .disableAutoConnect()
        .enableReconnection();
    socket = io(serverAddress, options.build());

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
    socket.on("new-message", (data) => handleCustomEvent("new-message", data));
    socket.on("updated-message", (data) => handleCustomEvent("updated-message", data));
    socket.on("message-send-errors", (data) => handleCustomEvent("message-send-errors", data));
    socket.on("group-name-change", (data) => handleCustomEvent("group-name-change", data));
    socket.on("participant-removed", (data) => handleCustomEvent("participant-removed", data));
    socket.on("participant-added", (data) => handleCustomEvent("participant-added", data));
    socket.on("participant-left", (data) => handleCustomEvent("participant-left", data));
    socket.on("chat-read-status-changed", (data) => handleCustomEvent("chat-read-status-change", data));
    socket.on("typing-indicator", (data) => handleCustomEvent("typing-indicator", data));

    socket.connect();
  }

  void closeSocket() {
    socket.dispose();
    state.value = SocketState.disconnected;
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
        state.value = SocketState.error;
        // After 5 seconds of an error, we should retry the connection
        Timer(Duration(seconds: 5), () async {
          if (state.value == SocketState.connected) return;

          await fdb.fetchNewUrl();
          Get.reload<SocketService>(force: true);
        });
        return;
      default:
        return;
    }
  }

  void handleCustomEvent(String event, Map<String, dynamic> data) {
    // todo once event handlers are written
    switch (event) {
      case "new-message":
        return;
      case "updated-message":
        return;
      case "message-send-errors":
        return;
      case "group-name-change":
        return;
      case "participant-removed":
      case "participant-added":
      case "participant-left":
        return;
      case "chat-read-status-changed":
        return;
      case "typing-indicator":
        ChatController? currentChat = ChatManager().getChatControllerByGuid(data["guid"]);
        if (currentChat == null) return;
        if (data["display"]) {
          currentChat.displayTypingIndicator();
        } else {
          currentChat.hideTypingIndicator();
        }
        return;
      default:
        return;
    }
  }
}