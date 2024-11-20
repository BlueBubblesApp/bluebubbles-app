import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/utils/crypto_utils.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:socket_io_client/socket_io_client.dart';

SocketService socket = Get.isRegistered<SocketService>() ? Get.find<SocketService>() : Get.put(SocketService());

enum SocketState {
  connected,
  disconnected,
  error,
  connecting,
}

class SocketService extends GetxService {
  final Rx<SocketState> state = SocketState.connecting.obs;
  SocketState _lastState = SocketState.connecting;
  RxString lastError = "".obs;
  Timer? _reconnectTimer;
  late Socket socket;

  InternetConnection? internetConnection;
  StreamSubscription<InternetStatus>? internetConnectionListener;

  String get serverAddress => http.origin;
  String get password => ss.settings.guidAuthKey.value;

  @override
  void onInit() {
    super.onInit();

    Logger.debug("Initializing socket service...");
    startSocket();
    Connectivity().onConnectivityChanged.listen((event) {
      if (!event.contains(ConnectivityResult.wifi) &&
          !event.contains(ConnectivityResult.ethernet) &&
          http.originOverride != null) {
        Logger.info("Detected switch off wifi, removing localhost address...");
        http.originOverride = null;
      }
    });
    Logger.debug("Initialized socket service");
  }

  @override
  void onClose() {
    closeSocket();
    super.onClose();
  }

  void startSocket() {
    OptionBuilder options = OptionBuilder()
        .setQuery({"guid": password})
        .setTransports(['websocket', 'polling'])
        .setExtraHeaders(http.headers)
        // Disable so that we can create the listeners first
        .disableAutoConnect()
        .enableReconnection();
    socket = io(serverAddress, options.build());
    // placed here so that [socket] is still initialized
    if (isNullOrEmpty(serverAddress)) return;

    socket.onConnect((data) => handleStatusUpdate(SocketState.connected, data));
    socket.onReconnect((data) => handleStatusUpdate(SocketState.connected, data));

    socket.onReconnectAttempt((data) => handleStatusUpdate(SocketState.connecting, data));

    socket.onDisconnect((data) => handleStatusUpdate(SocketState.disconnected, data));

    socket.onConnectError((data) => handleStatusUpdate(SocketState.error, data));
    socket.onReconnectError((data) => handleStatusUpdate(SocketState.error, data));
    socket.onReconnectFailed((data) => handleStatusUpdate(SocketState.error, data));
    socket.onError((data) => handleStatusUpdate(SocketState.error, data));

    // custom events
    // only listen to these events from socket on web/desktop (FCM handles on Android)
    if (kIsWeb || kIsDesktop) {
      socket.on("group-name-change", (data) => ah.handleEvent("group-name-change", data, 'DartSocket'));
      socket.on("participant-removed", (data) => ah.handleEvent("participant-removed", data, 'DartSocket'));
      socket.on("participant-added", (data) => ah.handleEvent("participant-added", data, 'DartSocket'));
      socket.on("participant-left", (data) => ah.handleEvent("participant-left", data, 'DartSocket'));
      socket.on("incoming-facetime", (data) => ah.handleEvent("incoming-facetime", jsonDecode(data), 'DartSocket'));
    }

    socket.on("ft-call-status-changed", (data) => ah.handleEvent("ft-call-status-changed", data, 'DartSocket'));
    socket.on("new-message", (data) => ah.handleEvent("new-message", data, 'DartSocket'));
    socket.on("updated-message", (data) => ah.handleEvent("updated-message", data, 'DartSocket'));
    socket.on("typing-indicator", (data) => ah.handleEvent("typing-indicator", data, 'DartSocket'));
    socket.on("chat-read-status-changed", (data) => ah.handleEvent("chat-read-status-changed", data, 'DartSocket'));
    socket.on("imessage-aliases-removed", (data) => ah.handleEvent("imessage-aliases-removed", data, 'DartSocket'));

    // For some reason desktop needs a separate listener
    if (kIsDesktop) {
      internetConnection = InternetConnection.createInstance(
        customCheckOptions: [
          InternetCheckOption(
              uri: Uri.parse(serverAddress),
              timeout: const Duration(seconds: 5),
          ),
        ],
        useDefaultOptions: false,
      );

      internetConnectionListener = internetConnection!.onStatusChange.listen((InternetStatus status) {
        Logger.info("Internet status changed: $status");
        switch (status) {
          case InternetStatus.connected:
            reconnect();
          case InternetStatus.disconnected:
            disconnect();
        }
      });
    }

    socket.connect();
  }

  void disconnect() {
    if (isNullOrEmpty(serverAddress)) return;
    socket.disconnect();
    state.value = SocketState.disconnected;
  }

  void reconnect() {
    if (state.value == SocketState.connected || isNullOrEmpty(serverAddress)) return;
    state.value = SocketState.connecting;
    socket.connect();
  }

  void closeSocket() {
    if (isNullOrEmpty(serverAddress)) return;
    socket.dispose();
    internetConnectionListener?.cancel();
    state.value = SocketState.disconnected;
  }

  void restartSocket() {
    closeSocket();
    startSocket();
  }

  void forgetConnection() {
    closeSocket();
    ss.settings.guidAuthKey.value = "";
    clearServerUrl(saveAdditionalSettings: ["guidAuthKey"]);
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
        notif.clearSocketError();
      case SocketState.disconnected:
        Logger.info("Disconnected from socket...");
        state.value = SocketState.disconnected;
      case SocketState.connecting:
        Logger.info("Connecting to socket...");
        state.value = SocketState.connecting;
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

          if (state.value == SocketState.connected) return;

          if (!ss.settings.keepAppAlive.value) {
            notif.createSocketError();
          }
        });
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
}
