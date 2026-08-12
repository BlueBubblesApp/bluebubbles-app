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

  /// Unsubscribe callbacks for every listener registered in [startSocket].
  ///
  /// `Socket.dispose()` only clears listeners registered on the socket itself.
  /// The reconnect/error events (`onError`, `onReconnect`, `onReconnectAttempt`,
  /// `onReconnectError`, `onReconnectFailed`) are registered on the underlying
  /// socket.io *Manager*, which `dispose()` never touches — so they have to be
  /// removed by hand or every restart stacks another copy of every handler.
  final List<Function()> _eventUnsubscribers = [];

  /// Whether the socket is *supposed* to be running.
  ///
  /// Flipped to false by [disconnect] when the lifecycle service backgrounds the
  /// app, and back to true when the app resumes. Async work that outlives the
  /// disconnect must not silently bring the connection back up — see
  /// [startSocket] and [_handleReconnectFailed].
  bool connectionDesired = true;

  static const Duration _socketExceptionLogThrottle = Duration(minutes: 1);

  /// `SocketException.address` is null for DNS failures — the hostname only ever
  /// appears inside the message, e.g.
  /// `Failed host lookup: 'example.com' (OS Error: ..., errno = 7)`.
  static final RegExp _hostLookupPattern = RegExp(r"Failed host lookup:\s*'([^']+)'");

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
    // startSocket() arms this too, but it bails out before that when no server is
    // configured yet — and we still want to react to connectivity changes then.
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
    // The lifecycle service disconnects the socket when the app is backgrounded.
    // Anything that tries to bring it back up from a background task (a scheduled
    // restart whose `fetchNewUrl()` was still in flight, a URL save, ...) has to be
    // ignored, or the socket is resurrected behind the user's back and burns
    // battery reconnecting to an unreachable server until the app is reopened.
    if (!connectionDesired) {
      Logger.info(tag: "SocketService", "Not starting socket — the app is backgrounded");
      return;
    }

    if (socket != null) {
      Logger.debug("Socket already exists, disposing previous instance before starting a new connection");
      _clearEventHandlers();
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
        // Always build a fresh Manager instead of reusing socket.io's global one.
        //
        // `io()` caches Managers by `scheme://host:port` and only bypasses that
        // cache when the requested namespace already exists on the cached Manager.
        // It computes the namespace from `Uri.parse(url).path` for the cache check
        // but from `path.isEmpty ? '/' : path` when actually creating the socket —
        // so for a URL with no path (which is exactly what `HttpSvc.origin` gives
        // us) the check looks for '' while the socket is stored under '/', never
        // matches, and every startSocket() silently returns the *same* Socket from
        // the *same* Manager. That made the connection un-restartable: the Manager
        // kept the auth query and headers it was first built with, and each restart
        // stacked another copy of every Manager-level listener.
        .enableForceNew()
        .enableReconnection()
        // Allow socket.io to make a few quick retries before we take over via
        // _handleReconnectFailed. Without a finite limit, onReconnectFailed
        // never fires and our restart+URL-refresh logic never runs.
        .setReconnectionAttempts(3)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000);
    final s = io(serverAddress, options.build());
    socket = s;

    // Every registration returns its own unsubscribe callback — keep them all so
    // teardown is deterministic regardless of which emitter the handler landed on.
    _eventUnsubscribers.addAll([
      s.onConnect((data) => handleStatusUpdate(SocketState.connected, data)),
      s.onReconnect((data) => handleStatusUpdate(SocketState.connected, data)),
      s.onReconnectAttempt((data) => handleStatusUpdate(SocketState.reconnecting, data)),
      s.onDisconnect((data) => handleStatusUpdate(SocketState.disconnected, data)),
      s.onConnectError((data) => handleStatusUpdate(SocketState.error, data)),
      s.onReconnectError((data) => handleStatusUpdate(SocketState.error, data)),
      s.onReconnectFailed((data) => _handleReconnectFailed(data)),
      s.onError((data) => handleStatusUpdate(SocketState.error, data)),
    ]);

    // custom events
    // only listen to these events from socket on web/desktop (FCM handles on Android)
    if (kIsWeb || kIsDesktop) {
      _eventUnsubscribers.addAll([
        s.on("group-name-change", (data) => MessageHandlerSvc.handleEvent("group-name-change", data, 'DartSocket')),
        s.on("participant-removed", (data) => MessageHandlerSvc.handleEvent("participant-removed", data, 'DartSocket')),
        s.on("participant-added", (data) => MessageHandlerSvc.handleEvent("participant-added", data, 'DartSocket')),
        s.on("participant-left", (data) => MessageHandlerSvc.handleEvent("participant-left", data, 'DartSocket')),
        s.on("incoming-facetime",
            (data) => MessageHandlerSvc.handleEvent("incoming-facetime", jsonDecode(data), 'DartSocket')),
      ]);
    }

    _eventUnsubscribers.addAll([
      s.on("ft-call-status-changed",
          (data) => MessageHandlerSvc.handleEvent("ft-call-status-changed", data, 'DartSocket')),
      s.on("new-message", (data) => MessageHandlerSvc.handleEvent("new-message", data, 'DartSocket')),
      s.on("updated-message", (data) => MessageHandlerSvc.handleEvent("updated-message", data, 'DartSocket')),
      s.on("typing-indicator", (data) => MessageHandlerSvc.handleEvent("typing-indicator", data, 'DartSocket')),
      s.on("chat-read-status-changed",
          (data) => MessageHandlerSvc.handleEvent("chat-read-status-changed", data, 'DartSocket')),
      s.on("imessage-aliases-removed",
          (data) => MessageHandlerSvc.handleEvent("imessage-aliases-removed", data, 'DartSocket')),
      // Live Find My updates. Re-broadcast through the event dispatcher rather than
      // letting the Find My controller hook the raw socket: the socket object is
      // replaced on every restart, so a listener attached directly to it silently
      // stops firing the first time the connection is cycled.
      s.on("new-findmy-location", (data) => EventDispatcherSvc.emit('new-findmy-location', data)),
    ]);

    // Re-arm connectivity monitoring — closeSocket()/disconnect() tear it down, and
    // without this it would stay dead for the rest of the process after the first
    // restart, silently stranding the localhost origin override on a cellular switch.
    _startConnectivitySubscription();

    s.connect();

    if (kIsDesktop && Platform.isWindows) {
      internetConnection = InternetConnection.createInstance(
        customCheckOptions: [
          InternetCheckOption(
            uri: Uri.parse(serverAddress),
            timeout: const Duration(seconds: 3),
            responseStatusFn: (_) => true,
          ),
        ],
        useDefaultOptions: false,
        triggerStream: Connectivity().onConnectivityChanged,
      );

      internetConnectionListener = internetConnection!.onStatusChange.listen((InternetStatus status) {
        Logger.info("Internet status changed: $status");
        if (status == InternetStatus.disconnected) {
          handleStatusUpdate(SocketState.error, null);
        } else if (state.value == SocketState.error) {
          Logger.info("Internet reconnected, restarting socket...");
          restartSocket();
        }
      });
    }
  }

  /// Removes every listener registered by [startSocket], including the ones that
  /// live on the socket.io Manager rather than the socket itself.
  void _clearEventHandlers() {
    for (final unsubscribe in _eventUnsubscribers) {
      unsubscribe();
    }
    _eventUnsubscribers.clear();
  }

  /// Intentionally takes the socket down — used by the lifecycle service when the
  /// app is backgrounded. The connection stays down until something explicitly
  /// asks for it back by flipping [connectionDesired].
  void disconnect() {
    connectionDesired = false;
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
    connectionDesired = true;
    state.value = SocketState.connecting;
    socket?.connect();
    _startConnectivitySubscription();
  }

  void closeSocket() {
    if (isNullOrEmpty(serverAddress)) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    internetConnectionListener?.cancel();
    internetConnectionListener = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _clearEventHandlers();
    socket?.dispose();
    // Drop the reference too. Callers such as the FCM handler use
    // `socket?.connected` to decide whether the socket will deliver a message for
    // them — a disposed-but-still-referenced socket makes that answer a guess.
    socket = null;
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

    // Nothing to schedule if the app has been backgrounded — the socket is meant
    // to stay down until the app is reopened.
    if (!connectionDesired) return;

    final int index = min(_scheduledRestartAttempt, _scheduledRestartBackoff.length - 1);
    final Duration delay = _scheduledRestartBackoff[index];
    _scheduledRestartAttempt++;

    Logger.warn("Socket exhausted reconnect attempts — scheduling restart in ${delay.inSeconds}s");
    handleStatusUpdate(SocketState.error, data);

    _reconnectTimer = Timer(delay, () async {
      if (state.value == SocketState.connected || !connectionDesired) {
        return;
      }

      bool restartFailed = false;
      _isScheduledRestartInProgress = true;
      try {
        Logger.info("Attempting to fetch new URL and restart socket...");
        // Don't let fetchNewUrl() restart the socket for us — it saves the URL with
        // `force: true`, which would restart the connection here and then again
        // below, tearing down a socket that was still mid-handshake.
        final String? newUrl = await fdb.fetchNewUrl(restartSocket: false);
        if (newUrl != null && newUrl != serverAddress) {
          Logger.info("Server URL changed from $serverAddress to $newUrl");
        }

        // fetchNewUrl() hits the network and can take a while; the app may have
        // been backgrounded in the meantime, in which case restarting here would
        // resurrect a socket the lifecycle service just deliberately killed.
        if (!connectionDesired) {
          Logger.info(tag: "SocketService", "App was backgrounded during scheduled restart — leaving socket down");
          return;
        }

        restartSocket();
      } catch (e, stack) {
        Logger.error("Scheduled socket restart failed", error: e, trace: stack, tag: "SocketService");
        restartFailed = true;
      } finally {
        _isScheduledRestartInProgress = false;
      }

      // This timer is the only thing that revives the connection once socket.io
      // has exhausted its own attempts. If the restart threw there is no socket
      // left to emit reconnect_failed, so re-arm the loop by hand — otherwise a
      // single failure leaves the app offline until it's reopened.
      if (restartFailed && connectionDesired && state.value != SocketState.connected) {
        _handleReconnectFailed(null);
      }
    });
  }

  /// Best-effort hostname for [e].
  ///
  /// `SocketException.address` is only populated once a name has been resolved to
  /// an `InternetAddress`, so it is always null for the one failure that actually
  /// needs a hostname — a failed DNS lookup. Read it out of the message instead,
  /// and fall back to the configured server rather than printing "unknown".
  String _hostFor(SocketException e) {
    final String? configuredHost = Uri.tryParse(serverAddress)?.host;
    return e.address?.host ??
        _hostLookupPattern.firstMatch(e.message)?.group(1) ??
        (isNullOrEmpty(configuredHost) ? 'unknown' : configuredHost!);
  }

  void handleSocketException(SocketException e) {
    String msg = e.message;
    if (msg.contains("Failed host lookup")) {
      lastError.value = "Failed to resolve hostname: ${_hostFor(e)}";
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
      // Report the window we actually covered rather than the throttle duration.
      // Suppression starts at the previous log, but the next one only happens when
      // an error arrives after the throttle expires — which can be much later than
      // the throttle itself if the errors are sporadic. Printing the throttle
      // duration made a slow trickle look like a burst.
      final int elapsed = now.difference(_lastSocketExceptionLogAt!).inSeconds;
      summary = ' (suppressed $_suppressedSocketExceptionCount similar errors over the last ${elapsed}s)';
    }

    Logger.error("Socket exception: ${lastError.value}$summary", error: e);
    _suppressedSocketExceptionCount = 0;
    _lastSocketExceptionSignature = signature;
    _lastSocketExceptionLogAt = now;
  }
}
