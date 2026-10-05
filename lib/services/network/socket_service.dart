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
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
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
///  1. **Reconnecting after a transient failure** — owned by socket.io. It is
///     configured with unlimited attempts and a capped exponential backoff, and
///     this class schedules no retries of its own. socket.io reuses its Manager and
///     re-resolves DNS on each attempt, which covers every case where the server is
///     simply unreachable for a while. The one gap is a disconnect socket.io
///     initiated itself, which stops its retry loop for good — see [_socketGaveUp].
///
///  2. **Rebuilding the connection** — owned here, because a Manager's URI and auth
///     options are fixed at construction. Needed when the server moved, or when
///     socket.io has given up on the current one. See [_runUrlDiscovery].
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

  /// Ceiling on a single discovery round.
  ///
  /// Neither leg of the fetch has a timeout of its own — on desktop it awaits a
  /// Firebase RTDB stream (`ref.onValue.first`), on Android two method-channel
  /// round trips. Without this a hung read leaves [_urlDiscoveryInProgress] set
  /// for the rest of the process, which silently disables rediscovery — and
  /// rediscovery is the only recovery from [_socketGaveUp].
  static const Duration _urlDiscoveryTimeout = Duration(seconds: 60);

  /// The server's engine.io heartbeat takes up to three minutes to notice a dead connection
  /// and can't change until the server rewrite, so the client runs its own.
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _heartbeatTimeout = Duration(seconds: 5);
  static const int _heartbeatMissLimit = 2;

  /// Collapse window for repeated identical error logs.
  static const Duration _errorLogThrottle = Duration(minutes: 1);

  /// Upper bound on tracked error signatures. Signatures embed OS error codes and
  /// messages, so a flapping network can mint new ones indefinitely.
  static const int _maxTrackedErrorSignatures = 32;

  /// Collapse window for connectivity-triggered reconnects. One network
  /// transition emits several events (`[none]`, then `[wifi]`), and each rebuild
  /// is expensive, so only the last event in a burst is acted on.
  static const Duration _connectivityReconnectDebounce = Duration(seconds: 3);

  /// `SocketException.address` is null for DNS failures — the hostname only ever
  /// appears inside the message, e.g.
  /// `Failed host lookup: 'example.com' (OS Error: ..., errno = 7)`.
  static final RegExp _hostLookupPattern = RegExp(r"Failed host lookup:\s*'([^']+)'");

  // ── Connection state ───────────────────────────────────────────────────────

  /// The single source of truth for connection status. Everything that changes
  /// the connection — including [disconnect] and [closeSocket] — writes here, and
  /// [handleStatusUpdate] compares against it rather than keeping a shadow copy
  /// that could drift out of sync with those direct writes.
  final Rx<SocketState> state = SocketState.connecting.obs;
  RxString lastError = "".obs;

  /// Whether the server rejected the current password.
  final RxBool authFailed = false.obs;
  String? _rejectedPassword;
  Socket? socket;

  /// The origin [socket] was built against; a Manager can't change it afterwards.
  String? _dialedOrigin;

  /// Unsubscribe callbacks for every listener registered in [startSocket].
  ///
  /// `Socket.dispose()` only clears listeners on the socket itself. The
  /// reconnect/error events (`onError`, `onReconnect`, `onReconnectAttempt`,
  /// `onReconnectError`, `onReconnectFailed`) live on the underlying socket.io
  /// *Manager*, which `dispose()` never touches, so they must be removed by hand.
  final List<Function()> _eventUnsubscribers = [];

  // ── 3. Lifecycle gating ────────────────────────────────────────────────────

  /// Whether the socket is *supposed* to be running.
  ///
  /// Set false by [disconnect] when the lifecycle service backgrounds the app,
  /// and true again by [resumeConnection]. Async work that outlives a disconnect
  /// must not silently bring the connection back up, so every path that can start
  /// a socket checks this — including after its own awaits.
  ///
  /// Route writes through [_setConnectionDesired] rather than assigning directly:
  /// this flag is what makes an intentional background disconnect stick, and a
  /// stray write is close to impossible to diagnose without the transition log.
  bool _connectionDesired = true;
  bool get connectionDesired => _connectionDesired;

  void _setConnectionDesired(bool value) {
    if (_connectionDesired == value) return;
    _connectionDesired = value;
    Logger.debug(tag: _tag, "Connection is now ${value ? "wanted" : "unwanted"}");
  }

  // ── URL rediscovery state ──────────────────────────────────────────────────

  Timer? _urlDiscoveryTimer;
  bool _urlDiscoveryInProgress = false;
  int _urlDiscoveryAttempt = 0;

  // ── Error log throttling state ─────────────────────────────────────────────

  /// Throttle bookkeeping per error signature, ordered least-recently-logged
  /// first so [_pruneErrorLog] can evict from the front.
  ///
  /// Deliberately not a single "last signature" pair: socket.io emits more than
  /// one error per failed attempt, and when the payloads differ (a `SocketException`
  /// from the engine, the bare String `'timeout'` from `Manager.open`) a single-slot
  /// throttle alternates and suppresses nothing at all.
  final Map<String, _ErrorLogState> _errorLog = {};

  StreamSubscription? _connectivitySubscription;
  bool _networkAvailable = true;
  Timer? _connectivityReconnectTimer;

  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeoutTimer;
  int _heartbeatMisses = 0;

  String get serverAddress => HttpSvc.origin;
  String get password => SettingsSvc.settings.guidAuthKey.value;

  void init() {
    Logger.debug("Initializing socket service...");
    startSocket();
    _checkConnectivity();
    Logger.debug("Initialized socket service");
  }

  void _startConnectivitySubscription() {
    if (_connectivitySubscription != null) return;
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged, onError: _logConnectivityError);
  }

  void _checkConnectivity() {
    unawaited(Connectivity().checkConnectivity().then(_onConnectivityChanged, onError: _logConnectivityError));
  }

  // Throws on Linux without NetworkManager (or a Flatpak without DBus access to it).
  void _logConnectivityError(Object e) => Logger.warn(tag: _tag, "Connectivity check failed", error: e);

  void _onConnectivityChanged(List<ConnectivityResult> event) {
    if (!connectionDesired) return;

    if (event.every((result) => result == ConnectivityResult.none)) {
      // Windows reports `none` whenever NCSI finds no internet, even with the server reachable on the LAN,
      // so desktop leaves it to socket.io's retries.
      if (kIsDesktop || !_networkAvailable) return;
      _networkAvailable = false;
      Logger.info(tag: _tag, "Network lost — closing socket until it's back");
      closeSocket();
      _reportOffline();
      return;
    }

    if (!event.contains(ConnectivityResult.wifi) &&
        !event.contains(ConnectivityResult.ethernet) &&
        HttpSvc.originOverride != null) {
      Logger.info("Detected switch off wifi, removing localhost address...");
      NetworkTasks.setOriginOverride(null);
      followOrigin();
    }

    if (!_networkAvailable) {
      _networkAvailable = true;
      Logger.info(tag: _tag, "Network is back — connecting");
      startSocket();
    } else {
      _scheduleConnectivityReconnect();
    }
  }

  void _reportOffline() {
    lastError.value = "No network connection";
    state.value = SocketState.error;
  }

  /// Cuts short socket.io's backoff wait when the network comes back.
  ///
  /// A network change is the only cheap signal that a retry might now succeed, and
  /// with the backoff ceiling at [_reconnectDelayMax] the next scheduled attempt
  /// can be a minute out. `Socket.connect()` can't shorten that — it no-ops while
  /// `Manager.reconnecting` is set — so the connection has to be rebuilt.
  /// A socket that still reads as connected gets a liveness check instead.
  void _scheduleConnectivityReconnect() {
    if (!connectionDesired) return;
    _connectivityReconnectTimer?.cancel();
    _connectivityReconnectTimer = Timer(_connectivityReconnectDebounce, () {
      _connectivityReconnectTimer = null;
      checkConnection();
      if (!_shouldReconnectOnNetworkChange) return;
      Logger.info(tag: _tag, "Network changed while disconnected — rebuilding socket");
      restartSocket();
    });
  }

  /// Only worth rebuilding from the states that are *waiting* on socket.io's backoff.
  ///
  /// `connecting`/`reconnecting` mean an attempt is already in flight, and there is no
  /// delay to cut short — tearing those down would throw away a handshake that may
  /// well be about to succeed. A doomed in-flight attempt needs no help either: it
  /// fails into `error`, and socket.io's next attempt re-resolves DNS on its own.
  bool get _shouldReconnectOnNetworkChange =>
      connectionDesired && (state.value == SocketState.error || state.value == SocketState.disconnected);

  // ── Connection lifecycle ───────────────────────────────────────────────────

  void startSocket() {
    // Background tasks that can start a socket — a URL save, an in-flight discovery
    // run — must not resurrect it behind the user's back after the lifecycle
    // service intentionally took it down.
    if (!connectionDesired) {
      Logger.info(tag: _tag, "Not starting socket — the app is backgrounded");
      return;
    }

    _startConnectivitySubscription();

    if (socket != null) {
      Logger.debug("Socket already exists, disposing previous instance before starting a new connection");
      _clearEventHandlers();
      socket?.dispose();
      socket = null;
    }

    if (!_networkAvailable) {
      _reportOffline();
      return;
    }

    // Validate server address before attempting to connect
    if (isNullOrEmpty(serverAddress)) {
      _failToStart("Server address not configured");
      return;
    }

    // Validate that server address is a valid URL
    Uri? uri = Uri.tryParse(serverAddress);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      _failToStart("Invalid server URL format: $serverAddress");
      return;
    }

    if (password != _rejectedPassword) authFailed.value = false;
    Logger.info("Starting socket connection to $serverAddress");
    _dialedOrigin = serverAddress;

    OptionBuilder options = OptionBuilder()
        .setQuery({"guid": password})
        .setTransports(['websocket', 'polling'])
        .setExtraHeaders(HttpSvc.headers)
        // WebsocketAdapter allows socket io client
        // to trust user certificates on Android
        .setHttpClientAdapter(WebsocketAdapter())
        // Disable so that we can create the listeners first
        .disableAutoConnect()
        // Required for the socket to be restartable at all. Without it, `io()`
        // reuses its cached Manager for this scheme://host:port and hands back the
        // *same* Socket — pinned to the auth query and headers it was first built
        // with. (Its cache check looks up the namespace as '' while the socket is
        // stored under '/', so the miss that would bypass the cache never happens.)
        .enableForceNew()
        // Reconnection is socket.io's job — concern 1 above. Attempts are left
        // unlimited (the library default) so the backoff can grow to
        // _reconnectDelayMax and settle there. Do NOT call
        // setReconnectionAttempts(): a finite cap makes socket.io emit
        // `reconnect_failed` and stop for good, which only [_socketGaveUp] recovers
        // from, and then only on the rediscovery timer's schedule.
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
      // Unreachable while attempts are unlimited; socket.io only emits this on a
      // finite cap. Kept so that a future cap surfaces in the logs rather than as
      // an app that mysteriously stopped receiving.
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

    // Report the attempt before making it. closeSocket() leaves the state at
    // `disconnected`, so without this a deliberate rebuild reads as "offline"
    // rather than "connecting" for the whole handshake.
    handleStatusUpdate(SocketState.connecting, null);
    s.connect();
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
    _setConnectionDesired(false);
    _cancelUrlDiscovery();
    // No isNullOrEmpty(serverAddress) guard: every call below is null-safe, and
    // bailing early here used to leave a live, listening socket behind while
    // connectionDesired said the connection was down — a state nothing recovers
    // from, since every restart path now refuses to run.
    _connectivityReconnectTimer?.cancel();
    _connectivityReconnectTimer = null;
    _stopHeartbeat();
    socket?.disconnect();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    state.value = SocketState.disconnected;
  }

  /// Marks the connection as wanted again and clears the rediscovery backoff, so a
  /// returning user isn't left waiting out a long timer. Called on app resume.
  ///
  /// Deliberately does not clear [_urlDiscoveryInProgress]: that flag belongs to an
  /// in-flight future which clears it in its own `finally`, and [_urlDiscoveryTimeout]
  /// bounds how long that can take. Clearing it here would let a second discovery
  /// run start alongside the first and race it to `restartSocket()`.
  void resumeConnection() {
    _setConnectionDesired(true);
    _cancelUrlDiscovery();
    // No connectivity events arrive while backgrounded.
    _networkAvailable = true;
    _checkConnectivity();
  }

  /// Tears the connection down completely, including its Manager.
  ///
  /// Unlike [disconnect] this does not change [connectionDesired] — it is the
  /// teardown half of [restartSocket], not a statement about whether the socket
  /// should be running.
  void closeSocket() {
    _cancelUrlDiscovery();
    // No isNullOrEmpty(serverAddress) guard — see [disconnect]. The guard used to
    // sit above this teardown, so restartSocket() with an unresolvable origin left
    // the old socket connected and listening while startSocket() bailed out on
    // validation, contradicting this method's entire contract.
    _connectivityReconnectTimer?.cancel();
    _connectivityReconnectTimer = null;
    _stopHeartbeat();
    _clearEventHandlers();
    socket?.dispose();
    // Drop the reference too: the FCM handler reads `socket?.connected` to decide
    // whether the socket will deliver a message, and a disposed-but-still-
    // referenced socket makes that answer a guess.
    socket = null;
    // Set directly rather than through handleStatusUpdate — the disconnect event
    // that would normally report this was just unsubscribed above.
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

  /// Rebuilds onto [serverAddress] if it no longer matches what the socket dials.
  void followOrigin() {
    if (!connectionDesired || socket == null || _dialedOrigin == serverAddress) return;
    Logger.info(tag: _tag, "Server origin moved from $_dialedOrigin to $serverAddress — rebuilding socket");
    restartSocket();
  }

  void forgetConnection() {
    closeSocket();
    SettingsSvc.settings.guidAuthKey.value = "";
    clearServerUrl(saveAdditionalSettings: ["guidAuthKey"]);
  }

  // ── URL rediscovery ────────────────────────────────────────────────────────

  /// Whether socket.io has stopped retrying the current connection on its own.
  ///
  /// A DISCONNECT packet from the server (or any explicit close) sets
  /// `skipReconnect` on the Manager, which permanently ends its retry loop no
  /// matter how many attempts are left. That is the one failure socket.io will not
  /// recover from, so it needs a rebuild rather than patience.
  bool get _socketGaveUp {
    final Socket? s = socket;
    if (s == null) return true;
    return s.io.skipReconnect ?? false;
  }

  /// Called on every connection error, and on a disconnect socket.io won't retry.
  /// socket.io is normally already retrying on its own schedule, so all this does
  /// is start the clock on "maybe the server moved".
  ///
  /// Errors arrive several times per failed attempt, so this is deliberately
  /// idempotent: the first one arms the timer and the rest are ignored until that
  /// run completes.
  void _noteConnectionFailure() {
    if (!connectionDesired) return;
    // fetchNewUrl() returns immediately without finishedSetup, so there is nothing
    // to discover — and arming anyway would log a failure per cycle throughout
    // first-run setup, when having no server address yet is the expected state.
    if (!SettingsSvc.settings.finishedSetup.value) return;
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

  /// Asks Firebase for the current server URL and rebuilds the socket if what we
  /// dial has changed, or if socket.io is no longer retrying on its own.
  ///
  /// A Manager's URI and auth options are fixed at construction, so a new address
  /// cannot be picked up without a rebuild. Otherwise the existing reconnect loop
  /// is already doing the right thing and is left alone.
  ///
  /// The rebuild deliberately happens *after* the `finally` rather than inside the
  /// `try`: [startSocket] can fail synchronously (an unusable address), and its
  /// attempt to re-arm this loop is dropped on the floor while
  /// [_urlDiscoveryInProgress] is still set — which left the app permanently
  /// offline with no socket, no retry loop and no pending timer.
  Future<void> _runUrlDiscovery() async {
    _urlDiscoveryTimer = null;

    // socket.io may have reconnected while the timer was pending, or the app may
    // have been backgrounded. Either way there is nothing to rediscover.
    if (!connectionDesired || state.value == SocketState.connected) {
      _cancelUrlDiscovery();
      return;
    }

    bool rebuild = false;
    _urlDiscoveryInProgress = true;
    try {
      Logger.info(tag: _tag, "Connection still failing — checking whether the server URL changed");

      // fetchNewUrl() persists whatever it finds via saveNewServerUrl(force: true).
      // restartSocket: false stops that from cycling the connection as a side
      // effect, keeping the decision to restart here, next to the comparison.
      await fdb.fetchNewUrl(restartSocket: false).timeout(_urlDiscoveryTimeout);

      // The fetch is a network round trip; the app can be backgrounded during it.
      if (!connectionDesired) {
        Logger.info(tag: _tag, "App was backgrounded during URL discovery — leaving socket down");
        return;
      }

      if (serverAddress != _dialedOrigin) {
        Logger.info(tag: _tag, "Server URL changed from $_dialedOrigin to $serverAddress — rebuilding socket");
        rebuild = true;
      } else if (_socketGaveUp) {
        // Same address, but socket.io has stopped retrying it — a rebuild is the
        // only thing that will bring the connection back.
        Logger.info(tag: _tag, "Server URL unchanged but socket.io is no longer retrying — rebuilding socket");
        rebuild = true;
      } else if (HttpSvc.originOverride != null) {
        // The remote address didn't move, but we're dialing a LAN override that was
        // resolved against a network we may have since left — and a wifi-to-wifi
        // change never fires the connectivity listener that would drop it. Re-probe
        // instead of trusting it indefinitely. detectLocalhost() clears the override
        // before probing, so a failed probe falls back to the remote URL rather than
        // leaving us pinned to a dead local address.
        Logger.info(tag: _tag, "Server URL unchanged — re-probing the local address override");
        await NetworkTasks.detectLocalhost().timeout(_urlDiscoveryTimeout);
      } else {
        Logger.debug(tag: _tag, "Server URL unchanged — leaving socket.io to keep retrying");
      }
    } catch (e, stack) {
      Logger.warn("Failed to check for a new server URL", error: e, trace: stack, tag: _tag);
    } finally {
      _urlDiscoveryInProgress = false;
    }

    if (!connectionDesired) return;
    if (rebuild) restartSocket();

    // Still failing — check again later, backing off. Skipped when the rebuild's
    // own failure path already armed the timer, so the backoff advances once per
    // round rather than twice.
    if (state.value != SocketState.connected && _urlDiscoveryTimer == null) {
      _scheduleUrlDiscovery();
    }
  }

  /// The server rejects a bad password by kicking the socket without a reason; HTTP gives a 401.
  Future<void> _checkAuth() async {
    final String attempted = password;
    try {
      await HttpSvc.server.ping();
    } on DioException catch (e) {
      if (e.response?.statusCode != 401 || attempted != password) return;
      _rejectedPassword = attempted;
      authFailed.value = true;
      handleStatusUpdate(SocketState.error, "Incorrect password");
    } catch (_) {}
  }

  /// The password can also be fixed server-side, so a flagged failure is re-checked on connect.
  Future<void> _clearAuthFailureIfAccepted() async {
    try {
      await HttpSvc.server.ping();
      authFailed.value = false;
      _rejectedPassword = null;
      NetworkTasks.onConnect();
    } catch (_) {}
  }

  // ── Heartbeat ──────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;
    _heartbeatMisses = 0;
  }

  /// Checks a "connected" socket now instead of waiting for the next heartbeat.
  void checkConnection() => _sendHeartbeat();

  /// Rebuilds rather than calling `connect()`: socket.io still believes the dead
  /// connection is up.
  void _sendHeartbeat() {
    final Socket? s = socket;
    if (s == null || state.value != SocketState.connected || _heartbeatTimeoutTimer != null) return;

    _heartbeatTimeoutTimer = Timer(_heartbeatTimeout, () {
      _heartbeatTimeoutTimer = null;
      // socket.io may already be reconnecting on its own.
      if (state.value != SocketState.connected) return;
      // One late ack on a slow link isn't enough to throw away a working socket; retry straight away.
      if (++_heartbeatMisses < _heartbeatMissLimit) return _sendHeartbeat();
      Logger.warn(tag: _tag, "Server missed $_heartbeatMisses heartbeats in a row — rebuilding socket");
      restartSocket();
    });

    // Read-only; get-server-config would delete the server's live password. The payload must be
    // non-null or the server's `(_, cb)` handler never acks.
    s.emitWithAck("get-fcm-client", {}, ack: ([_, _]) {
      if (!identical(s, socket) || _heartbeatTimeoutTimer == null) return;
      _heartbeatTimeoutTimer!.cancel();
      _heartbeatTimeoutTimer = null;
      _heartbeatMisses = 0;
    });
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
    final bool stateChanged = state.value != status;

    switch (status) {
      case SocketState.connected:
        if (stateChanged) {
          state.value = SocketState.connected;
          _cancelUrlDiscovery();
          _resetErrorLog();
          // A rejected password still connects briefly, and the sync would just 401.
          if (!authFailed.value) NetworkTasks.onConnect();
          Logger.info("Socket connected successfully to $serverAddress");
          _startHeartbeat();
          if (authFailed.value) unawaited(_clearAuthFailureIfAccepted());
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

        if (data == 'io server disconnect') unawaited(_checkAuth());

        // Concern 1 (socket.io retries) does not cover a disconnect it initiated
        // itself — see [_socketGaveUp]. Hand those to the rediscovery timer, which
        // rebuilds the connection whether or not the URL moved.
        if (_socketGaveUp) _noteConnectionFailure();
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
    // Removed rather than read so the re-insert below moves this signature to the
    // back, leaving iteration order least-recently-seen first for _pruneErrorLog().
    final _ErrorLogState? previous = _errorLog.remove(signature);

    if (previous != null && now.difference(previous.lastLoggedAt) < _errorLogThrottle) {
      previous.suppressed++;
      _errorLog[signature] = previous;
      return;
    }

    String summary = '';
    if (previous != null && previous.suppressed > 0) {
      // Report the window actually covered, not the throttle duration: the next log
      // only happens once an error arrives after the throttle expires, which can be
      // much later, and printing the throttle made a slow trickle look like a burst.
      final int elapsed = now.difference(previous.lastLoggedAt).inSeconds;
      summary = ' (suppressed ${previous.suppressed} similar errors over the last ${elapsed}s)';
    }

    Logger.error("$message$summary", error: error, tag: _tag);
    _errorLog[signature] = _ErrorLogState(now);
    _pruneErrorLog();
  }

  void _pruneErrorLog() {
    while (_errorLog.length > _maxTrackedErrorSignatures) {
      _errorLog.remove(_errorLog.keys.first);
    }
  }

  void _resetErrorLog() => _errorLog.clear();

  /// Reports a socket that could not even be constructed.
  ///
  /// Goes through the same throttle as connection errors — this path repeats on the
  /// rediscovery schedule — and arms rediscovery, since an unusable address is
  /// exactly the case where asking Firebase for a new one is the only way out.
  void _failToStart(String reason) {
    lastError.value = reason;
    state.value = SocketState.error;
    _logSocketError(signature: 'start|$reason', message: "Cannot start socket: $reason");
    _noteConnectionFailure();
  }
}

/// Throttle bookkeeping for one error signature. See [SocketService._errorLog].
class _ErrorLogState {
  _ErrorLogState(this.lastLoggedAt);

  DateTime lastLoggedAt;
  int suppressed = 0;
}
