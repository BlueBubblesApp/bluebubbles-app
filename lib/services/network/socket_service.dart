import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
  reconnecting,
}

class SocketService {
  final Rx<SocketState> state = SocketState.connecting.obs;
  SocketState _lastState = SocketState.connecting;
  RxString lastError = "".obs;
  Timer? _reconnectTimer;
  Socket? socket;
  bool _isScheduledRestartInProgress = false;
  DateTime? _lastSocketExceptionLogAt;
  String? _lastSocketExceptionSignature;
  int _suppressedSocketExceptionCount = 0;
  int _scheduledRestartAttempt = 0;

  static const Duration _socketExceptionLogThrottle = Duration(minutes: 1);
  static const List<Duration> _scheduledRestartBackoff = [
    Duration.zero,
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
  ];

  InternetConnection? internetConnection;
  StreamSubscription<InternetStatus>? internetConnectionListener;
  StreamSubscription? _connectivitySubscription;

  String get serverAddress => HttpSvc.origin;
  String get password => SettingsSvc.settings.guidAuthKey.value;

  void init() {
    Logger.debug("Initializing socket service...");
    startSocket();
    _startConnectivitySubscription();
    Logger.debug("Initialized socket service");
  }

  void _startConnectivitySubscription() {
    if (kIsDesktop && Platform.isWindows) return;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((event) {
      if (!event.contains(ConnectivityResult.wifi) &&
          !event.contains(ConnectivityResult.ethernet) &&
          HttpSvc.originOverride != null) {
        Logger.info("Detected switch off wifi, removing localhost address...");
        NetworkTasks.setOriginOverride(null);
      }
    });
  }

  void startSocket() {
    if (socket != null) {
      Logger.debug("Socket already exists, disposing previous instance before starting a new connection");
      socket?.dispose();
      socket = null;
    }

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
        .setReconnectionDelayMax(5000);
    socket = io(serverAddress, options.build());

    socket?.onConnect((data) => handleStatusUpdate(SocketState.connected, data));
    socket?.onReconnect((data) => handleStatusUpdate(SocketState.connected, data));

    socket?.onReconnectAttempt((data) => handleStatusUpdate(SocketState.reconnecting, data));

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
            // 3s is too aggressive for a busy LAN server — a single slow probe
            // would falsely report "no internet". 5s tolerates normal jitter.
            timeout: const Duration(seconds: 5),
            responseStatusFn: (_) => true,
          ),
        ],
        useDefaultOptions: false,
        triggerStream: Connectivity().onConnectivityChanged,
      );

      internetConnectionListener = internetConnection!.onStatusChange.listen((InternetStatus status) {
        Logger.info("Internet status changed: $status");
        if (status == InternetStatus.disconnected) {
          // A single failed reachability probe must NOT tear down a live
          // websocket. socket.io already detects real drops via
          // onDisconnect/onConnectError; forcing SocketState.error here on every
          // transient LAN/probe timeout manufactures a restart loop (the cause
          // of repeated disconnects on the home network). Only escalate if the
          // socket truly isn't connected.
          if (socket?.connected != true && state.value != SocketState.connected) {
            handleStatusUpdate(SocketState.error, null);
          }
        } else if (state.value == SocketState.error && socket?.connected != true) {
          Logger.info("Internet reconnected, restarting socket...");
          restartSocket();
        }
      });
    }
  }

  void disconnect() {
    if (isNullOrEmpty(serverAddress)) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    socket?.disconnect();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    state.value = SocketState.disconnected;
  }

  void reconnect() {
    if (state.value == SocketState.connected || isNullOrEmpty(serverAddress)) return;
    state.value = SocketState.connecting;
    socket?.connect();
    _startConnectivitySubscription();
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

  void resetScheduledRestartBackoff({bool cancelPendingTimer = false}) {
    if (_isScheduledRestartInProgress) {
      Logger.info(tag: "SocketService", "Reset socket scheduled restart backoff on app resume");
    }

    _scheduledRestartAttempt = 0;
    _isScheduledRestartInProgress = false;
    if (cancelPendingTimer) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
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
          resetScheduledRestartBackoff();
          _suppressedSocketExceptionCount = 0;
          _lastSocketExceptionLogAt = null;
          _lastSocketExceptionSignature = null;
          NetworkTasks.onConnect();
          Logger.info("Socket connected successfully to $serverAddress");
        }
      case SocketState.reconnecting:
        if (stateChanged) {
          Logger.info("Reconnecting to socket at $serverAddress");
          state.value = SocketState.reconnecting;
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
        bool shouldLogGenericError = true;

        if (data is SocketException) {
          handleSocketException(data);
          errorDetails = lastError.value;
          shouldLogGenericError = false;
        } else if (data is Map) {
          errorDetails = data.toString();
        } else if (data != null) {
          errorDetails = data.toString();
        }

        if (shouldLogGenericError) {
          Logger.error("Socket error connecting to $serverAddress: $errorDetails");
        }
        lastError.value = errorDetails;
        state.value = SocketState.error;
    }
  }

  /// Called when socket.io exhausts all reconnect attempts. Schedules a
  /// restart after a short delay so we can refresh the server URL first.
  void _handleReconnectFailed(dynamic data) {
    if ((_reconnectTimer?.isActive ?? false) || _isScheduledRestartInProgress) {
      return;
    }

    final int index = min(_scheduledRestartAttempt, _scheduledRestartBackoff.length - 1);
    final Duration delay = _scheduledRestartBackoff[index];
    _scheduledRestartAttempt++;

    Logger.warn("Socket exhausted reconnect attempts — scheduling restart in ${delay.inSeconds}s");
    handleStatusUpdate(SocketState.error, data);

    _reconnectTimer = Timer(delay, () async {
      if (state.value == SocketState.connected) {
        return;
      }

      _isScheduledRestartInProgress = true;
      try {
        Logger.info("Attempting to fetch new URL and restart socket...");
        final String? newUrl = await fdb.fetchNewUrl();
        if (newUrl != null && newUrl != serverAddress) {
          Logger.info("Server URL changed from $serverAddress to $newUrl");
        }

        restartSocket();
      } finally {
        _isScheduledRestartInProgress = false;
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

    final DateTime now = DateTime.now();
    final String signature = '${e.address?.host ?? ''}|${e.osError?.errorCode ?? ''}|$msg';
    final bool isSameError = signature == _lastSocketExceptionSignature;
    final bool isWithinThrottle =
        _lastSocketExceptionLogAt != null && now.difference(_lastSocketExceptionLogAt!) < _socketExceptionLogThrottle;

    if (isSameError && isWithinThrottle) {
      _suppressedSocketExceptionCount++;
      return;
    }

    String summary = '';
    if (isSameError && _suppressedSocketExceptionCount > 0) {
      summary =
          ' (suppressed $_suppressedSocketExceptionCount similar errors in the last ${_socketExceptionLogThrottle.inSeconds}s)';
    }

    Logger.error("Socket exception: ${lastError.value}$summary", error: e);
    _suppressedSocketExceptionCount = 0;
    _lastSocketExceptionSignature = signature;
    _lastSocketExceptionLogAt = now;
  }
}
