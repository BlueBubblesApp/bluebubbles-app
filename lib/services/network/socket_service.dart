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
import 'websocket_adapter.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
SocketService get SocketSvc => GetIt.I<SocketService>();

enum SocketState {
  connected,
  disconnected,
  error,
  connecting,
}

class SocketService {
  final Rx<SocketState> state = SocketState.connecting.obs;
  SocketState _lastState = SocketState.connecting;
  RxString lastError = "".obs;
  Timer? _reconnectTimer;
  Socket? socket;

  // Tracks a URL fetched from Firebase during reconnect (#2770).
  // Applied in-memory only; persisted to disk once the connection succeeds.
  String? _pendingFirebaseUrl;

  InternetConnection? internetConnection;
  StreamSubscription<InternetStatus>? internetConnectionListener;
  StreamSubscription? _connectivitySubscription;

  String get serverAddress => HttpSvc.origin;
  String get password => SettingsSvc.settings.guidAuthKey.value;

  void init() {
    Logger.debug("Initializing socket service...");
    startSocket();

    if (!kIsDesktop || !Platform.isWindows) {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((event) {
        if (!event.contains(ConnectivityResult.wifi) &&
            !event.contains(ConnectivityResult.ethernet) &&
            HttpSvc.originOverride != null) {
          Logger.info("Detected switch off wifi, removing localhost address...");
          HttpSvc.originOverride = null;
        }
      });
    }

    Logger.debug("Initialized socket service");
  }

  void startSocket() {
    // Validate server address before attempting to connect
    if (isNullOrEmpty(serverAddress)) {
      Logger.warn("Cannot start socket: server address is empty");
      lastError.value = "Server address not configured";
      state.value = SocketState.error;
      return;
    }

    // Validate that server address is a valid URL
    Uri? uri = Uri.tryParse(serverAddress);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      Logger.error("Invalid server address: $serverAddress");
      lastError.value = "Invalid server URL format";
      state.value = SocketState.error;
      return;
    }

    Logger.info("Starting socket connection to $serverAddress");

    OptionBuilder options = OptionBuilder()
        .setQuery({"guid": password})
        .setTransports(['websocket', 'polling'])
        .setExtraHeaders(HttpSvc.headers)
        // WebsocketAdapter allows socket io client
        // to trust user certificates on Android
        .setHttpClientAdapter(WebsocketAdapter())
        // Disable so that we can create the listeners first
        .disableAutoConnect()
        .enableReconnection()
        // Allow socket.io to make a few quick retries before we take over via
        // _handleReconnectFailed. Without a finite limit, onReconnectFailed
        // never fires and our restart+URL-refresh logic never runs.
        .setReconnectionAttempts(3)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        // Support sub-path deployments behind reverse proxies (#2668).
        // The socket.io endpoint is at {basePath}/socket.io, not just /socket.io.
        .setPath(HttpSvc.socketPath);
    socket = io(serverAddress, options.build());

    socket?.onConnect((data) => handleStatusUpdate(SocketState.connected, data));
    socket?.onReconnect((data) => handleStatusUpdate(SocketState.connected, data));

    socket?.onReconnectAttempt((data) => handleStatusUpdate(SocketState.connecting, data));

    socket?.onDisconnect((data) => handleStatusUpdate(SocketState.disconnected, data));

    socket?.onConnectError((data) => handleStatusUpdate(SocketState.error, data));
    socket?.onReconnectError((data) => handleStatusUpdate(SocketState.error, data));
    socket?.onReconnectFailed((data) => _handleReconnectFailed(data));
    socket?.onError((data) => handleStatusUpdate(SocketState.error, data));

    // custom events
    // only listen to these events from socket on web/desktop (FCM handles on Android)
    if (kIsWeb || kIsDesktop) {
      socket?.on("group-name-change", (data) => MessageHandlerSvc.handleEvent("group-name-change", data, 'DartSocket'));
      socket?.on(
          "participant-removed", (data) => MessageHandlerSvc.handleEvent("participant-removed", data, 'DartSocket'));
      socket?.on("participant-added", (data) => MessageHandlerSvc.handleEvent("participant-added", data, 'DartSocket'));
      socket?.on("participant-left", (data) => MessageHandlerSvc.handleEvent("participant-left", data, 'DartSocket'));
      socket?.on("incoming-facetime",
          (data) => MessageHandlerSvc.handleEvent("incoming-facetime", jsonDecode(data), 'DartSocket'));
    }

    socket?.on("ft-call-status-changed",
        (data) => MessageHandlerSvc.handleEvent("ft-call-status-changed", data, 'DartSocket'));
    socket?.on("new-message", (data) => MessageHandlerSvc.handleEvent("new-message", data, 'DartSocket'));
    socket?.on("updated-message", (data) => MessageHandlerSvc.handleEvent("updated-message", data, 'DartSocket'));
    socket?.on("typing-indicator", (data) => MessageHandlerSvc.handleEvent("typing-indicator", data, 'DartSocket'));
    socket?.on("chat-read-status-changed",
        (data) => MessageHandlerSvc.handleEvent("chat-read-status-changed", data, 'DartSocket'));
    socket?.on("imessage-aliases-removed",
        (data) => MessageHandlerSvc.handleEvent("imessage-aliases-removed", data, 'DartSocket'));

    socket?.connect();

    if (kIsDesktop && Platform.isWindows) {
      internetConnection = InternetConnection.createInstance(
        customCheckOptions: [
          InternetCheckOption(
            uri: Uri.parse(serverAddress),
            responseStatusFn: (_) => true,
          ),
        ],
        useDefaultOptions: false,
      );

      internetConnectionListener = internetConnection!.onStatusChange.listen((InternetStatus status) {
        Logger.info("Internet status changed: $status");
        switch (status) {
          case InternetStatus.connected:
            socket?.connect();
          case InternetStatus.disconnected:
            socket?.disconnect();
        }
      });
    }
  }

  void disconnect() {
    if (isNullOrEmpty(serverAddress)) return;
    socket?.disconnect();
    state.value = SocketState.disconnected;
  }

  void reconnect() {
    if (state.value == SocketState.connected || isNullOrEmpty(serverAddress)) return;
    state.value = SocketState.connecting;
    socket?.connect();
  }

  void closeSocket() {
    if (isNullOrEmpty(serverAddress)) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    internetConnectionListener?.cancel();
    _connectivitySubscription?.cancel();
    socket?.dispose();
    state.value = SocketState.disconnected;
  }

  void restartSocket() {
    closeSocket();
    startSocket();
  }

  void forgetConnection() {
    closeSocket();
    SettingsSvc.settings.guidAuthKey.value = "";
    clearServerUrl(saveAdditionalSettings: ["guidAuthKey"]);
  }

  Future<Map<String, dynamic>> sendMessage(String event, Map<String, dynamic> message) {
    if (socket == null) return Future.error(StateError('Socket not connected'));
    final completer = Completer<Map<String, dynamic>>();

    socket!.emitWithAck(event, message, ack: (response) {
      if (response['encrypted'] == true) {
        response['data'] = jsonDecode(decryptAESCryptoJS(response['data'], password));
      }

      if (!completer.isCompleted) {
        completer.complete(response);
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => Future.error(TimeoutException('Socket message timed out', const Duration(seconds: 30))),
    );
  }

  void handleStatusUpdate(SocketState status, dynamic data) {
    // Don't skip state updates entirely - we need to process errors even if state hasn't changed
    bool stateChanged = _lastState != status;
    _lastState = status;

    switch (status) {
      case SocketState.connected:
        if (stateChanged) {
          state.value = SocketState.connected;
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          // Firebase URL trial succeeded — persist it now (#2770).
          if (_pendingFirebaseUrl != null) {
            Logger.info("Firebase URL ${_pendingFirebaseUrl} confirmed working — persisting");
            unawaited(saveNewServerUrl(_pendingFirebaseUrl!, restartSocket: false));
            _pendingFirebaseUrl = null;
          }
          NetworkTasks.onConnect();
          NotificationsSvc.clearSocketError();
          Logger.info("Socket connected successfully to $serverAddress");
        }
      case SocketState.disconnected:
        if (stateChanged) {
          Logger.info("Disconnected from socket at $serverAddress");
          state.value = SocketState.disconnected;
        }
      case SocketState.connecting:
        if (stateChanged) {
          Logger.info("Attempting to connect to socket at $serverAddress");
          state.value = SocketState.connecting;
        }
      case SocketState.error:
        // Parse and log the error details
        String errorDetails = "Unknown error";

        if (data is SocketException) {
          handleSocketException(data);
          errorDetails = lastError.value;
        } else if (data is Map) {
          errorDetails = data.toString();
        } else if (data != null) {
          errorDetails = data.toString();
        }

        Logger.error("Socket error connecting to $serverAddress: $errorDetails");
        lastError.value = errorDetails;
        state.value = SocketState.error;
    }
  }

  /// Called when socket.io exhausts all reconnect attempts. Schedules a
  /// restart after a short delay so we can refresh the server URL first.
  void _handleReconnectFailed(dynamic data) {
    Logger.warn("Socket exhausted reconnect attempts — scheduling restart");
    handleStatusUpdate(SocketState.error, data);

    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      if (state.value == SocketState.connected) return;

      Logger.info("Attempting to fetch new URL and restart socket...");
      final String currentUrl = serverAddress;
      final String? newUrl = await fdb.fetchNewUrl();
      if (newUrl != null && newUrl != currentUrl) {
        // Apply in-memory without persisting to disk (#2770).
        // Only persist after the connection actually succeeds (see handleStatusUpdate).
        Logger.info("Trying Firebase URL $newUrl (current: $currentUrl) — will persist only if connection succeeds");
        SettingsSvc.settings.serverAddress.value = newUrl;
        _pendingFirebaseUrl = newUrl;
      } else {
        _pendingFirebaseUrl = null;
      }

      restartSocket();

      if (!SettingsSvc.settings.keepAppAlive.value) {
        NotificationsSvc.createSocketError();
      }
    });
  }

  void handleSocketException(SocketException e) {
    String msg = e.message;
    if (msg.contains("Failed host lookup")) {
      lastError.value = "Failed to resolve hostname: ${e.address?.host ?? 'unknown'}";
    } else if (msg.contains("Connection refused")) {
      lastError.value = "Connection refused - server may be offline";
    } else if (msg.contains("Connection timed out")) {
      lastError.value = "Connection timed out";
    } else if (msg.contains("Network is unreachable")) {
      lastError.value = "Network is unreachable";
    } else if (msg.contains("Certificate") || msg.contains("CERTIFICATE")) {
      lastError.value = "SSL/TLS certificate error: $msg";
    } else {
      lastError.value = msg;
    }

    Logger.error("Socket exception: ${lastError.value}", error: e);
  }
}
