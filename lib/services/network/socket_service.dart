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

/// Owns the single socket.io connection to the BlueBubbles server.
///
/// Three distinct concerns are deliberately kept separate here, because
/// conflating them is what previously made this class hard to reason about:
///
///  1. **Reconnecting after a transient failure** — owned entirely by socket.io.
///     It is configured with unlimited attempts and a capped exponential backoff,
///     and this class does not schedule retries of its own. socket.io reuses its
///     Manager and re-resolves DNS on each attempt, which covers every case where
///     the server is simply unreachable for a while.
///
///  2. **Rediscovering a server that has moved** — owned here, because socket.io
///     cannot know the URL changed. A Manager's URI and auth options are fixed at
///     construction, so a genuinely new address is the one situation that needs
///     the socket torn down and rebuilt. See [_runUrlDiscovery].
///
///  3. **Not running at all while the app is backgrounded** — owned here via
///     [connectionDesired]. See [disconnect] / [resumeConnection].
class SocketService {
  static const String _tag = "SocketService";

  // ── 1. Reconnection policy (handed to socket.io) ───────────────────────────

  /// Delay before socket.io's first reconnect attempt. It doubles from here,
  /// with jitter, up to [_reconnectDelayMax].
  static const Duration _reconnectDelay = Duration(seconds: 1);

  /// Ceiling for socket.io's reconnect backoff. A server that stays unreachable
  /// settles at one cheap attempt per minute instead of hammering it.
  static const Duration _reconnectDelayMax = Duration(minutes: 1);

  // ── 2. URL rediscovery policy (owned here) ─────────────────────────────────

  /// How long the connection must have been failing before we start asking
  /// Firebase whether the server moved.
  static const Duration _urlDiscoveryInitialDelay = Duration(seconds: 30);

  /// Ceiling for the gap between URL checks. Server addresses change rarely and
  /// each check is a Firebase auth + read, so this backs off hard.
  static const Duration _urlDiscoveryMaxDelay = Duration(minutes: 15);

  /// Collapse window for repeated identical error logs.
  static const Duration _errorLogThrottle = Duration(minutes: 1);

  /// `SocketException.address` is null for DNS failures — the hostname only ever
  /// appears inside the message, e.g.
  /// `Failed host lookup: 'example.com' (OS Error: ..., errno = 7)`.
  static final RegExp _hostLookupPattern = RegExp(r"Failed host lookup:\s*'([^']+)'");

  // ── Connection state ───────────────────────────────────────────────────────

  final Rx<SocketState> state = SocketState.connecting.obs;
  SocketState _lastState = SocketState.connecting;
  RxString lastError = "".obs;
  Socket? socket;

  /// Unsubscribe callbacks for every listener registered in [startSocket].
  ///
  /// `Socket.dispose()` only clears listeners registered on the socket itself.
  /// The reconnect/error events (`onError`, `onReconnect`, `onReconnectAttempt`,
  /// `onReconnectError`, `onReconnectFailed`) are registered on the underlying
  /// socket.io *Manager*, which `dispose()` never touches — so they have to be
  /// removed by hand or every restart stacks another copy of every handler.
  final List<Function()> _eventUnsubscribers = [];

  // ── 3. Lifecycle gating ────────────────────────────────────────────────────

  /// Whether the socket is *supposed* to be running.
  ///
  /// Set false by [disconnect] when the lifecycle service backgrounds the app,
  /// and true again by [resumeConnection]. Async work that outlives a disconnect
  /// must not silently bring the connection back up, so every path that can start
  /// a socket checks this — including after its own awaits.
  bool connectionDesired = true;

  // ── URL rediscovery state ──────────────────────────────────────────────────

  Timer? _urlDiscoveryTimer;
  bool _urlDiscoveryInProgress = false;
  int _urlDiscoveryAttempt = 0;

  // ── Error log throttling state ─────────────────────────────────────────────

  DateTime? _lastErrorLogAt;
  String? _lastErrorSignature;
  int _suppressedErrorCount = 0;

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

  // ── Connection lifecycle ───────────────────────────────────────────────────

  void startSocket() {
    // The lifecycle service takes the socket down when the app is backgrounded.
    // Anything that tries to bring it back up from a background task — a URL save,
    // a discovery run that was still in flight — has to be ignored, or the socket
    // is resurrected behind the user's back and reconnects against an unreachable
    // server until the app is reopened.
    if (!connectionDesired) {
      Logger.info(tag: _tag, "Not starting socket — the app is backgrounded");
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
        // Reconnection is socket.io's job, not ours. Attempts are deliberately left
        // unlimited (the library default) so its exponential backoff can grow to
        // _reconnectDelayMax and stay there.
        //
        // Do NOT call setReconnectionAttempts() here. A finite limit makes socket.io
        // emit `reconnect_failed` and stop forever, and nothing in this class will
        // revive the connection — the app just goes quietly offline until it is
        // restarted. An earlier version capped it at 3 purely to get a hook for URL
        // rediscovery; that now has its own timer and does not need the cap.
        .enableReconnection()
        .setReconnectionDelay(_reconnectDelay.inMilliseconds)
        .setReconnectionDelayMax(_reconnectDelayMax.inMilliseconds);
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
      s.onError((data) => handleStatusUpdate(SocketState.error, data)),
      // Unreachable while reconnection attempts are unlimited — socket.io only
      // emits this when it hits a finite cap. Registered anyway so that if the
      // policy above is ever changed, "the client gave up" shows up in the logs
      // instead of presenting as an app that mysteriously stopped receiving.
      s.onReconnectFailed((_) => Logger.warn(
          tag: _tag,
          "socket.io stopped reconnecting — reconnection attempts are capped somewhere, "
          "so this connection will not recover on its own")),
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
          // Pass a description rather than null — the error path falls back to
          // "Unknown error" for a null payload, which tells nobody anything.
          handleStatusUpdate(SocketState.error, "No internet connection");
        } else if (state.value == SocketState.error) {
          // Skip the wait for socket.io's next scheduled attempt now that we know
          // the network is back.
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

  /// Intentionally takes the socket down and keeps it down — used by the lifecycle
  /// service when the app is backgrounded. Nothing brings it back until
  /// [resumeConnection] (or an explicit user action) flips [connectionDesired].
  void disconnect() {
    connectionDesired = false;
    _cancelUrlDiscovery();
    if (isNullOrEmpty(serverAddress)) return;
    socket?.disconnect();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    state.value = SocketState.disconnected;
  }

  /// Marks the connection as wanted again and clears the rediscovery backoff, so a
  /// returning user isn't left waiting out a long timer. Called on app resume.
  void resumeConnection() {
    connectionDesired = true;
    _cancelUrlDiscovery();
  }

  /// Ensures the socket is up. Safe to call at any time — if socket.io is already
  /// retrying, this is a no-op.
  void reconnect() {
    if (isNullOrEmpty(serverAddress)) return;
    connectionDesired = true;
    if (socket == null) {
      startSocket();
      return;
    }
    if (state.value == SocketState.connected) return;
    state.value = SocketState.connecting;
    socket?.connect();
    _startConnectivitySubscription();
  }

  /// Tears the connection down completely, including its Manager.
  ///
  /// Unlike [disconnect] this does not change [connectionDesired] — it is the
  /// teardown half of [restartSocket], not a statement about whether the socket
  /// should be running.
  void closeSocket() {
    _cancelUrlDiscovery();
    if (isNullOrEmpty(serverAddress)) return;
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

  /// Rebuilds the connection from scratch.
  ///
  /// Only needed when something socket.io cannot re-read at runtime has changed:
  /// the server URL, the auth guid, or the request headers. Transient failures do
  /// not need this — socket.io's own reconnect already re-resolves DNS and redials.
  void restartSocket() {
    closeSocket();
    startSocket();
  }

  void forgetConnection() {
    closeSocket();
    SettingsSvc.settings.guidAuthKey.value = "";
    clearServerUrl(saveAdditionalSettings: ["guidAuthKey"]);
  }

  // ── URL rediscovery ────────────────────────────────────────────────────────

  /// Called on every connection error. socket.io is already retrying on its own
  /// schedule, so all this does is start the clock on "maybe the server moved".
  ///
  /// Errors arrive several times per failed attempt, so this is deliberately
  /// idempotent: the first one arms the timer and the rest are ignored until that
  /// run completes.
  void _noteConnectionFailure() {
    if (!connectionDesired) return;
    if (_urlDiscoveryTimer != null || _urlDiscoveryInProgress) return;
    _scheduleUrlDiscovery();
  }

  void _scheduleUrlDiscovery() {
    _urlDiscoveryTimer?.cancel();

    final int shift = min(_urlDiscoveryAttempt, 5);
    final int ms = min(
      _urlDiscoveryInitialDelay.inMilliseconds << shift,
      _urlDiscoveryMaxDelay.inMilliseconds,
    );
    _urlDiscoveryAttempt++;

    Logger.debug(tag: _tag, "Will check for a new server URL in ${Duration(milliseconds: ms).inSeconds}s");
    _urlDiscoveryTimer = Timer(Duration(milliseconds: ms), _runUrlDiscovery);
  }

  void _cancelUrlDiscovery() {
    _urlDiscoveryTimer?.cancel();
    _urlDiscoveryTimer = null;
    _urlDiscoveryAttempt = 0;
    // _urlDiscoveryInProgress is intentionally left alone — it belongs to the
    // in-flight future, which clears it in its own finally and re-checks
    // connectionDesired before acting on the result.
  }

  /// Asks Firebase for the current server URL and rebuilds the socket only if the
  /// address actually moved.
  ///
  /// A Manager's URI and auth options are fixed at construction, so a new address
  /// is the one failure mode socket.io's reconnect cannot recover from by itself.
  /// If the URL is unchanged, the existing reconnect loop is already doing the
  /// right thing and is left alone.
  Future<void> _runUrlDiscovery() async {
    _urlDiscoveryTimer = null;

    // socket.io may have reconnected while the timer was pending, or the app may
    // have been backgrounded. Either way there is nothing to rediscover.
    if (!connectionDesired || state.value == SocketState.connected) {
      _cancelUrlDiscovery();
      return;
    }

    _urlDiscoveryInProgress = true;
    try {
      final String previousOrigin = serverAddress;
      Logger.info(tag: _tag, "Connection still failing — checking whether the server URL changed");

      // fetchNewUrl() persists whatever it finds via saveNewServerUrl(force: true).
      // restartSocket: false stops that from cycling the connection as a side
      // effect, keeping the decision to restart here, next to the comparison.
      await fdb.fetchNewUrl(restartSocket: false);

      // The fetch is a network round trip; the app can be backgrounded during it.
      if (!connectionDesired) {
        Logger.info(tag: _tag, "App was backgrounded during URL discovery — leaving socket down");
        return;
      }

      // Compare the resolved origin rather than the returned string: that is what
      // the socket actually dials, and it also moves when saveNewServerUrl clears
      // a stale localhost origin override.
      if (serverAddress != previousOrigin) {
        Logger.info(tag: _tag, "Server URL changed from $previousOrigin to $serverAddress — rebuilding socket");
        restartSocket();
        return;
      }

      Logger.debug(tag: _tag, "Server URL unchanged — leaving socket.io to keep retrying");
    } catch (e, stack) {
      Logger.warn("Failed to check for a new server URL", error: e, trace: stack, tag: _tag);
    } finally {
      _urlDiscoveryInProgress = false;
    }

    // Still failing on the same address — check again later, backing off.
    if (connectionDesired && state.value != SocketState.connected) {
      _scheduleUrlDiscovery();
    }
  }

  // ── Messaging ──────────────────────────────────────────────────────────────

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

  // ── State reporting ────────────────────────────────────────────────────────

  void handleStatusUpdate(SocketState status, dynamic data) {
    // Don't skip state updates entirely - we need to process errors even if state hasn't changed
    bool stateChanged = _lastState != status;
    _lastState = status;

    switch (status) {
      case SocketState.connected:
        if (stateChanged) {
          state.value = SocketState.connected;
          _cancelUrlDiscovery();
          _resetErrorLogThrottle();
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
        if (data is SocketException) {
          handleSocketException(data);
        } else {
          final String details = data?.toString() ?? "Unknown error";
          lastError.value = details;
          _logSocketError(
            signature: 'generic|$details',
            message: "Socket error connecting to $serverAddress: $details",
          );
        }
        state.value = SocketState.error;

        // socket.io handles retrying. This only starts the "did the server move?"
        // clock, and is a no-op if that check is already armed or running.
        _noteConnectionFailure();
    }
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

    _logSocketError(
      signature: '${e.address?.host ?? ''}|${e.osError?.errorCode ?? ''}|$msg',
      message: "Socket exception: ${lastError.value}",
      error: e,
    );
  }

  /// Logs a socket error, collapsing repeats of the same failure into one line
  /// with a suppression count.
  ///
  /// Every error path goes through here. socket.io emits several errors per failed
  /// attempt and retries indefinitely, so an unreachable server would otherwise
  /// produce a steady stream of identical lines for as long as it stays down.
  void _logSocketError({required String signature, required String message, Object? error}) {
    final DateTime now = DateTime.now();
    final bool isSameError = signature == _lastErrorSignature;
    final bool isWithinThrottle = _lastErrorLogAt != null && now.difference(_lastErrorLogAt!) < _errorLogThrottle;

    if (isSameError && isWithinThrottle) {
      _suppressedErrorCount++;
      return;
    }

    String summary = '';
    if (isSameError && _suppressedErrorCount > 0) {
      // Report the window actually covered rather than the throttle duration.
      // Suppression starts at the previous log, but the next one only happens once
      // an error arrives after the throttle expires — which can be much later than
      // the throttle itself if errors are sporadic. Printing the throttle duration
      // made a slow trickle look like a burst.
      final int elapsed = now.difference(_lastErrorLogAt!).inSeconds;
      summary = ' (suppressed $_suppressedErrorCount similar errors over the last ${elapsed}s)';
    }

    Logger.error("$message$summary", error: error, tag: _tag);
    _suppressedErrorCount = 0;
    _lastErrorSignature = signature;
    _lastErrorLogAt = now;
  }

  void _resetErrorLogThrottle() {
    _suppressedErrorCount = 0;
    _lastErrorLogAt = null;
    _lastErrorSignature = null;
  }
}
