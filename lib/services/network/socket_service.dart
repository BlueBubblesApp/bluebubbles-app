import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/network/network_tasks.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/firebase/database_manager.dart';
import 'package:bluebubbles/managers/firebase/fcm_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:socket_io_client/socket_io_client.dart';

SocketService socket = Get.isRegistered<SocketService>() ? Get.find<SocketService>() : Get.put(SocketService());

enum SocketState {
  connected,
  disconnected,
  error,
  connecting,
}

/// Class that manages foreground network requests from client to server, using
/// GET or POST requests.
class SocketService extends GetxService {
  final Rx<SocketState> state = SocketState.disconnected.obs;
  SocketState _lastState = SocketState.disconnected;
  late final Socket socket;
  
  String? get serverAddress => SettingsManager().settings.serverAddress.value;
  String get password => SettingsManager().settings.guidAuthKey.value;

  @override
  void onInit() {
    super.onInit();
    startSocket();    
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
    /*socket.on("new-message", handleNewMessage);
    socket.on("group-name-change", handleNewMessage);
    socket.on("participant-removed", handleNewMessage);
    socket.on("participant-added", handleNewMessage);
    socket.on("participant-left", handleNewMessage);
    socket.on("chat-read-status-changed", handleChatStatusChange);
    socket.on("typing-indicator", (_data) {
      if (!SettingsManager().settings.enablePrivateAPI.value) return;

      Map<String, dynamic> data = _data;
      ChatController? currentChat = ChatManager().getChatControllerByGuid(
          data["guid"]);
      if (currentChat == null) return;
      if (data["display"]) {
        currentChat.displayTypingIndicator();
      } else {
        currentChat.hideTypingIndicator();
      }
    });*/
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
        Timer(Duration(seconds: 5), () {
          if (state.value == SocketState.connected) return;

          fdb.fetchNewUrl();
          // todo connect to socket agan
        });
        return;
      default:
        return;
    }
  }
}