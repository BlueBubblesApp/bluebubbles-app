import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/services/isolates/isolate_actions.dart';
import 'package:bluebubbles/services/isolates/isolate_event.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// A base isolate manager for handling background tasks
/// This class can be extended to create specialized isolates with different entry points
class GlobalIsolate {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  ReceivePort? _exitPort;
  ReceivePort? _errorPort;
  SendPort? _sendPort;
  final Map<String, _RequestInfo> _pendingRequests = {};
  bool _shutdownPending = false;
  Completer<void>? _drainCompleter;
  final StreamController<dynamic> _controller = StreamController.broadcast();
  final Map<IsolateEvent, List<Function(dynamic)>> _eventListeners = {};
  bool _isRunning = false;
  bool _isStarting = false;
  Completer<void> _startCompleter = Completer<void>();

  /// Completer resolved when the spawned isolate sends back its SendPort.
  Completer<void>? _sendPortCompleter;
  final List<Future<void> Function()> _onStartedCallbacks = [];

  /// Timer for tracking isolate inactivity
  Timer? _idleTimer;

  /// Timeout duration for individual task requests
  final Duration taskTimeout;

  /// Timeout duration for isolate startup
  final Duration startupTimeout;

  /// Duration of inactivity before the isolate is automatically killed
  /// Set to null to disable auto-shutdown
  final Duration? idleTimeout;

  /// Stream of outputs from the isolate
  Stream<dynamic> get outputStream => _controller.stream;

  /// Whether the isolate is currently running
  bool get isRunning => _isRunning;

  /// Register a callback to be fired every time the isolate successfully starts
  /// (including restarts after idle timeout). Use this to re-sync runtime state
  /// such as [HttpSvc.originOverride] that is not persisted to disk.
  void addStartedCallback(Future<void> Function() callback) {
    _onStartedCallbacks.add(callback);
  }

  /// The name used for registering the isolate port
  /// Can be overridden by subclasses to have unique ports
  String get isolatePortName => 'GlobalIsolate';

  /// The debug name for the isolate
  /// Can be overridden by subclasses for better debugging
  String get isolateDebugName => 'GlobalIsolate';

  GlobalIsolate({
    this.taskTimeout = Duration.zero,
    this.startupTimeout = const Duration(seconds: kDebugMode ? 60 : 30),
    this.idleTimeout = const Duration(minutes: 5),
  });

  /// Starts the isolate if not already running
  Future<void> _ensureStarted() async {
    // If we think it's running, verify it's actually alive
    if (_isRunning) {
      // Simple sanity check - the exit port will notify us if it actually dies
      if (!_verifyIsolateAlive()) {
        Logger.warn('$isolateDebugName appears to be dead. Restarting...');
        _cleanupDeadIsolate();
      } else {
        return;
      }
    }
    if (_isStarting) {
      // Wait for startup to complete if already in progress
      return _startCompleter.future;
    }

    // Reset the completer if a previous startup attempt completed (successfully or with an
    // error).  Without this, any concurrent caller that arrives while this new attempt is
    // in-flight would receive the stale completed completer and immediately see the old
    // error rather than waiting for the new startup to finish.
    if (_startCompleter.isCompleted) {
      _startCompleter = Completer<void>();
    }

    // Clear any stale SendPort left over from a previous failed/timed-out attempt so
    // that _waitForSendPort does not complete prematurely on a dead port.
    _sendPort = null;
    // Fresh completer for this startup attempt.
    _sendPortCompleter = Completer<void>();

    _isStarting = true;
    // Only clear the shutdown flag if we're not in the middle of a requested drain —
    // a restart triggered by another code path (e.g. _cleanupDeadIsolate) must not
    // silently cancel a pending drainAndStop().
    if (_drainCompleter == null) {
      _shutdownPending = false;
    }

    try {
      // Create a new ReceivePort for this isolate instance
      _receivePort = ReceivePort();

      // Create exit and error ports to monitor isolate lifecycle
      _exitPort = ReceivePort();
      _errorPort = ReceivePort();

      // Set up listener for the new port
      _receivePort!.listen(_handleIsolateMessage);

      // Listen for isolate exit
      _exitPort!.listen((message) {
        Logger.warn('$isolateDebugName exited unexpectedly: $message');
        _handleIsolateExit();
      });

      // Listen for isolate errors
      _errorPort!.listen((message) {
        Logger.error('$isolateDebugName encountered an error: $message');
        // Note: errors don't necessarily mean the isolate died, just that an unhandled error occurred
      });

      // Register the receive port with a name so it can be found by other isolates
      IsolateNameServer.registerPortWithName(_receivePort!.sendPort, isolatePortName);

      Logger.debug('Starting $isolateDebugName...');
      // Pass only the ReceivePort's SendPort and the RootIsolateToken.
      // The action map is NOT passed via args — each entry point resolves its own
      // action map via the defaultActionMap parameter inside the spawned isolate,
      // which avoids any cross-isolate serialisation of function closures/typedefs.
      final rootToken = RootIsolateToken.instance;
      _isolate = await Isolate.spawn(
        getIsolateEntryPoint as void Function(List<dynamic>),
        [_receivePort!.sendPort, rootToken],
        debugName: isolateDebugName,
        onExit: _exitPort!.sendPort,
        onError: _errorPort!.sendPort,
      );
      Logger.debug('$isolateDebugName started.');

      // Wait for the SendPort from the spawned isolate
      await _waitForSendPort();

      _isRunning = true;
      _scheduleIdleShutdown();

      if (!_startCompleter.isCompleted) {
        _startCompleter.complete();
      }

      // Fire started callbacks (e.g. to re-sync origin override after idle restart)
      for (final cb in List.from(_onStartedCallbacks)) {
        unawaited(cb());
      }
    } catch (e) {
      if (!_startCompleter.isCompleted) {
        _startCompleter.completeError(e);
      }
      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _waitForSendPort() async {
    try {
      await _sendPortCompleter!.future.timeout(
        startupTimeout,
        onTimeout: () => throw TimeoutException(
          'Timeout waiting for isolate SendPort after ${startupTimeout.inSeconds}s',
        ),
      );
      Logger.debug('Received SendPort from isolate');
    } catch (e) {
      Logger.error('Failed to receive SendPort: $e');
      // Clean up the isolate if we failed to get the SendPort
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;
      _sendPort = null;
      _isRunning = false;
      rethrow;
    }
  }

  /// Stops the isolate process but keeps runtime listeners/state by default so
  /// lazy restarts continue to deliver events to existing subscribers.
  void stop({bool clearEventListeners = false, bool closeOutputStream = false}) {
    if (!_isRunning && !_isStarting) return;

    // Cancel the idle timer
    _idleTimer?.cancel();
    _idleTimer = null;

    // If we're mid-startup, fail the SendPort completer so _waitForSendPort unblocks.
    if (_isStarting && _sendPortCompleter != null && !_sendPortCompleter!.isCompleted) {
      _sendPortCompleter!.completeError('Isolate was stopped before SendPort was received');
    }

    // Unregister the named port when stopping
    IsolateNameServer.removePortNameMapping(isolatePortName);
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _receivePort = null;
    _exitPort?.close();
    _exitPort = null;
    _errorPort?.close();
    _errorPort = null;
    if (closeOutputStream) {
      _controller.close();
    }

    // Complete all pending requests with an error
    for (final requestInfo in _pendingRequests.values) {
      if (!requestInfo.completer.isCompleted) {
        requestInfo.completer.completeError('Isolate was stopped');
        requestInfo.timer?.cancel();
      }
    }

    _pendingRequests.clear();
    _shutdownPending = false;

    // Resolve any awaiter of drainAndStop() so they aren't left hanging.
    final drainCompleter = _drainCompleter;
    _drainCompleter = null;
    if (drainCompleter != null && !drainCompleter.isCompleted) {
      drainCompleter.complete();
    }

    if (clearEventListeners) {
      _eventListeners.clear();
    }
    _isolate = null;
    _sendPort = null;
    _isRunning = false;
    _isStarting = false;

    // Reset the start completer
    if (_startCompleter.isCompleted) {
      _startCompleter = Completer<void>();
    }
  }

  /// Requests graceful shutdown:
  /// - [broadcast] calls are still accepted during the drain; a new [send]
  ///   cancels the drain instead (a pending message means the app is active again)
  /// - stops the isolate once all pending requests complete (or immediately if none)
  ///
  /// Returns a Future that completes when the isolate has fully stopped.
  /// Safe to fire-and-forget with [unawaited] if the caller doesn't need to wait.
  Future<void> drainAndStop() {
    if (!_isRunning && !_isStarting) return Future.value();

    // Return the same future if a drain is already in progress.
    if (_drainCompleter != null) return _drainCompleter!.future;

    _shutdownPending = true;
    _drainCompleter = Completer<void>();

    if (_pendingRequests.isEmpty) {
      Logger.info('$isolateDebugName draining complete (0 pending). Stopping now.');
      stop(); // clears _drainCompleter and completes it
      return Future.value();
    }

    Logger.info(
      '$isolateDebugName drain requested with ${_pendingRequests.length} pending request(s). '
      'Will stop when all pending requests complete.',
    );
    return _drainCompleter!.future;
  }

  /// Cancels an in-progress drain because the app is active again (resumed, or a
  /// new [send] arrived — e.g. a background notification quick-reply). Keeps the
  /// isolate running and clears the reject flag so outgoing sends and incoming
  /// message writes are not dropped. No-op if nothing is draining.
  void cancelDrain() {
    if (_drainCompleter == null && !_shutdownPending) return;
    Logger.info('$isolateDebugName drain cancelled — new activity, keeping isolate alive.');
    _shutdownPending = false;
    final completer = _drainCompleter;
    _drainCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    // Restore normal idle-based shutdown so the isolate still stops if it goes idle.
    _scheduleIdleShutdown();
  }

  /// Closes the isolate and clears all listeners
  void close() {
    stop(clearEventListeners: true, closeOutputStream: true);
  }

  /// Register a listener for a specific event type
  void addEventListener(IsolateEvent event, Function(dynamic) listener) {
    if (!_eventListeners.containsKey(event)) {
      _eventListeners[event] = [];
    }
    _eventListeners[event]!.add(listener);
    Logger.debug('Registered listener for event: ${event.name}');
  }

  /// Remove a specific listener for an event type
  void removeEventListener(IsolateEvent event, Function(dynamic) listener) {
    if (_eventListeners.containsKey(event)) {
      _eventListeners[event]!.remove(listener);
      if (_eventListeners[event]!.isEmpty) {
        _eventListeners.remove(event);
      }
      Logger.debug('Removed listener for event: ${event.name}');
    }
  }

  /// Remove all listeners for a specific event type
  void removeAllEventListeners(IsolateEvent event) {
    if (_eventListeners.containsKey(event)) {
      _eventListeners.remove(event);
      Logger.debug('Removed all listeners for event: ${event.name}');
    }
  }

  /// Clear all event listeners
  void clearAllEventListeners() {
    _eventListeners.clear();
    Logger.debug('Cleared all event listeners');
  }

  /// Sends a request to the isolate and waits for a response
  Future<T> send<T>(IsolateRequestType type, {dynamic input, Duration? customTimeout}) async {
    // A new request means the app is active again. Cancel any in-progress drain
    // rather than rejecting — dropping a message (outgoing send or incoming DB
    // write) is far worse than delaying a graceful idle shutdown.
    if (_shutdownPending) {
      cancelDrain();
    }
    await _ensureStarted();

    final requestId = const Uuid().v4();
    final completer = Completer<T>();

    // Set up timeout if not disabled (zero duration means no timeout)
    Timer? timer;
    if ((customTimeout ?? taskTimeout) != Duration.zero) {
      timer = Timer(customTimeout ?? taskTimeout, () {
        if (_pendingRequests.containsKey(requestId)) {
          final requestInfo = _pendingRequests.remove(requestId)!;
          if (!requestInfo.completer.isCompleted) {
            requestInfo.completer.completeError('Request timeout after ${customTimeout ?? taskTimeout}');
          }
          _maybeStopAfterDrain();
        }
      });
    }

    _pendingRequests[requestId] = _RequestInfo(completer: completer, timer: timer, type: type);

    // Reset idle shutdown when new work is queued.
    _scheduleIdleShutdown();

    // Create a standard request message
    final message = IsolateRequest(uuid: requestId, type: type, data: input).toMap();

    _sendPort!.send(message);

    return completer.future;
  }

  /// Fire-and-forget send (no response expected)
  void broadcast(IsolateRequestType type, dynamic input) {
    _ensureStarted().then((_) {
      _scheduleIdleShutdown();

      // Create a standard request message with empty UUID since no response is expected
      final message = IsolateRequest(uuid: '', type: type, data: input).toMap();

      _sendPort!.send(message);
    });
  }

  void _handleIsolateMessage(dynamic message) {
    if (message is SendPort) {
      _sendPort = message;
      if (_sendPortCompleter != null && !_sendPortCompleter!.isCompleted) {
        _sendPortCompleter!.complete();
      }
      return;
    }

    if (message is Map<String, dynamic>) {
      // Check if this is an event message
      if (message.containsKey('event')) {
        try {
          final eventMessage = IsolateEventMessage.fromMap(message);
          _handleEvent(eventMessage);
          return;
        } catch (e) {
          Logger.error('Failed to parse event message: $e');
        }
      }

      // Otherwise, treat it as a response
      final isolateResponse = IsolateResponse.fromMap(message);
      final uuid = isolateResponse.uuid;

      if (uuid.isNotEmpty && _pendingRequests.containsKey(uuid)) {
        final requestInfo = _pendingRequests.remove(uuid)!;
        requestInfo.timer?.cancel();

        if (isolateResponse.ok) {
          requestInfo.completer.complete(isolateResponse.data);
        } else {
          requestInfo.completer.completeError(isolateResponse.error ?? 'Unknown error');
        }

        // Check drain first: if a stop was requested and this was the last in-flight
        // request, stop now rather than scheduling an idle timer that would be
        // immediately cancelled.
        if (_shutdownPending) {
          _maybeStopAfterDrain();
        } else {
          _scheduleIdleShutdown();
        }
      } else if (isolateResponse.data != null) {
        // Broadcast the response data
        _controller.add(isolateResponse.data);
      }
    } else {
      // Direct message from isolate (not wrapped in IsolateResponse)
      _controller.add(message);
    }
  }

  /// Handle an event from the isolate
  void _handleEvent(IsolateEventMessage eventMessage) {
    Logger.debug('Received event from isolate: ${eventMessage.type.name}');

    if (_eventListeners.containsKey(eventMessage.type)) {
      final listeners = List.from(_eventListeners[eventMessage.type]!);
      for (final listener in listeners) {
        try {
          listener(eventMessage.data);
        } catch (e, stack) {
          Logger.error('Error in event listener for ${eventMessage.type.name}: $e', trace: stack);
        }
      }
    }
  }

  void _maybeStopAfterDrain() {
    if (!_shutdownPending) return;
    if (_pendingRequests.isNotEmpty) return;
    Logger.info('$isolateDebugName draining complete. Stopping isolate.');
    stop();
  }

  /// Schedules isolate shutdown to happen [idleTimeout] after the latest activity.
  /// This avoids periodic polling and makes idle shutdown precise.
  void _scheduleIdleShutdown() {
    if (idleTimeout == null) return;

    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout!, () {
      if (!_isRunning) return;

      // Never stop while work is in flight. Re-schedule from "now" and check again.
      if (_pendingRequests.isNotEmpty) {
        _scheduleIdleShutdown();
        return;
      }

      Logger.info(
        '$isolateDebugName has been idle for ${idleTimeout!.inSeconds}s. Shutting down...',
      );
      stop();
    });
  }

  /// Verify that the isolate is actually alive and responsive
  bool _verifyIsolateAlive() {
    // Simple check: if we have a send port and isolate reference, assume it's alive
    // The exit port will notify us if it dies
    return _sendPort != null && _isolate != null;
  }

  /// Clean up a dead isolate without trying to kill it
  void _cleanupDeadIsolate() {
    Logger.warn('Cleaning up dead $isolateDebugName');

    // Don't try to kill the isolate since it's already dead
    // Just clean up our local state
    _receivePort?.close();
    _receivePort = null;
    _exitPort?.close();
    _exitPort = null;
    _errorPort?.close();
    _errorPort = null;

    // Try to unregister the named port (may fail if already unregistered)
    try {
      IsolateNameServer.removePortNameMapping(isolatePortName);
    } catch (e) {
      // Ignore errors - port may already be unregistered
    }

    // Complete all pending requests with an error
    for (final requestInfo in _pendingRequests.values) {
      if (!requestInfo.completer.isCompleted) {
        requestInfo.completer.completeError('Isolate died unexpectedly');
        requestInfo.timer?.cancel();
      }
    }
    _pendingRequests.clear();

    _isolate = null;
    _sendPort = null;
    _isRunning = false;

    // Reset the start completer
    if (_startCompleter.isCompleted) {
      _startCompleter = Completer<void>();
    }
  }

  /// Handle isolate exit (called when exit port receives a message)
  void _handleIsolateExit() {
    // Guard against double-cleanup but allow the startup case:
    // during startup _isRunning is false, so the old guard would wrongly skip cleanup.
    if (!_isRunning && !_isStarting) return;

    // If we're still waiting for the SendPort, fail the completer immediately so
    // _waitForSendPort() unblocks rather than waiting for the full startup timeout.
    if (_isStarting && _sendPortCompleter != null && !_sendPortCompleter!.isCompleted) {
      _sendPortCompleter!.completeError('Isolate exited before sending SendPort');
    }

    Logger.warn('$isolateDebugName has exited unexpectedly (isRunning=$_isRunning, isStarting=$_isStarting)');
    _cleanupDeadIsolate();
  }

  /// Get the isolate entry point function
  /// Override this in subclasses to provide a different entry point
  Function get getIsolateEntryPoint => _isolateEntryPoint;

  /// Get the action map for this isolate
  /// Override this in subclasses to provide a different action map
  Map<IsolateRequestType, IsolateAction> getActionMap() => IsolateActons.actions;

  /// Shared entry point logic for all isolates
  /// Accepts a custom initialization function to allow specialized isolates to load different services
  static Future<void> sharedIsolateEntryPoint(
    List<dynamic> args,
    Future<void> Function(RootIsolateToken?) initServices,
    Map<IsolateRequestType, IsolateAction> defaultActionMap,
  ) async {
    final SendPort sendPort = args[0];
    final RootIsolateToken? rootIsolateToken = args.length > 1 ? args[1] : null;
    // Use the action map supplied directly by the entry point (defaultActionMap).
    // This intentionally ignores args[2] — the action map is never passed across the
    // isolate boundary because serialising generic Map<K, typedef> values is fragile
    // and has been observed to cause a TypeError in debug/JIT that kills the isolate
    // before the SendPort handshake can complete.
    final Map<IsolateRequestType, IsolateAction> actionMap = defaultActionMap;

    // Store the send port for event emission (before initServices so events can fire during init)
    IsolateEventEmitter.setSendPort(sendPort);

    // Create a receiver for the isolate and send the SendPort back to the main isolate
    // immediately, BEFORE initServices runs.  Any messages the main isolate sends while
    // services are still initialising are buffered by ReceivePort and delivered once
    // receivePort.listen() is called below.  This prevents the startupTimeout from firing
    // when initServices is legitimately slow (e.g. JIT compilation in debug mode).
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    await initServices(rootIsolateToken);

    receivePort.listen((message) async {
      if (message is! Map<String, dynamic>) return;

      final isolateRequest = IsolateRequest.fromMap(message);
      final String uuid = isolateRequest.uuid;
      final type = isolateRequest.type;
      final dynamic data = isolateRequest.data;
      Logger.debug('Received request: $type');

      try {
        final IsolateAction? action = actionMap[type];
        if (action == null) {
          throw Exception('Unknown request type: $type');
        }

        final result = await action(data);
        sendPort.send(IsolateResponse.success(uuid: uuid, data: result).toMap());
        Logger.debug('Returning request: $type');
      } catch (e, s) {
        Logger.error('Error in isolate action: [$type] $e', trace: s);

        // Send standardized error response
        sendPort.send(
          IsolateResponse.error(uuid: uuid, error: e.toString(), message: "Error executing isolate action").toMap(),
        );
      }
    });
  }

  /// The isolate entry point - uses shared logic with global service initialization
  static Future<void> _isolateEntryPoint(List<dynamic> args) async {
    await sharedIsolateEntryPoint(
      args,
      StartupTasks.initGlobalIsolateServices,
      IsolateActons.actions,
    );
  }
}

/// Standard signature for all isolate-dispatchable action functions.
/// Every entry in the action map must conform to this type so that the
/// dispatch path is a single `await action(data)` without any runtime
/// string introspection.
typedef IsolateAction = Future<dynamic> Function(dynamic);

enum IsolateRequestType {
  // Test actions
  testReturnInput,
  testPrintInput,
  testThrowError,

  // App actions
  checkForUpdate,
  getFcmData,

  // Server actions
  checkForServerUpdate,
  getServerDetails,

  // Image actions
  convertImageToPng,
  readExifData,
  getGifDimensions,

  // Prefs actions
  saveReplyToMessageState,
  loadReplyToMessageState,
  syncAllSettings,
  syncSettings,

  // Messages actions
  getMessages,

  // Chat actions
  clearNotificationForChat,
  markAllChatsRead,
  markChatReadUnread,
  startTyping,
  stopTyping,
  saveChat,
  deleteChat,
  softDeleteChat,
  unDeleteChat,
  addMessageToChat,
  loadSupplementalData,
  syncLatestMessages,
  bulkSyncChats,
  getMessagesAsync,
  getParticipantsAsync,
  clearTranscriptAsync,
  getChatsAsync,

  // Handle actions
  saveHandleAsync,
  bulkSaveHandlesAsync,
  findOneHandleAsync,
  findHandlesAsync,

  // ContactV2 actions (new contact service)
  syncContactsToHandles,
  getStoredContactIds,
  findOneContact,
  getContactsForHandles,
  getContactByAddress,
  getAllContacts,
  fetchNetworkContacts,
  getContactAvatar,
  uploadContactsV2,

  // Attachment actions
  saveAttachmentAsync,
  bulkSaveAttachmentsAsync,
  replaceAttachmentAsync,
  findOneAttachmentAsync,
  findAttachmentsAsync,
  deleteAttachmentAsync,

  // Network actions
  setOriginOverride,

  // Sync actions
  performIncrementalSync,
  bulkSyncData,

  // Log actions
  getLogs,

  // Send message actions (routed through isolate so sends survive backgrounding)
  sendTextMessage,
  sendTapback,
  sendMultipartMessage,
  sendAttachmentMessage,

  // Message actions
  replaceMessage,
  deleteMessage,
  softDeleteMessage,
  fetchAssociatedMessagesAsync,
  saveMessageAsync,
  findOneAsync,
  findAsync,
}

/// Internal class to track pending requests
class _RequestInfo<T> {
  final Completer<T> completer;
  final Timer? timer;
  final IsolateRequestType type;

  _RequestInfo({required this.completer, this.timer, required this.type});
}

/// A standard request format for isolate communication
class IsolateRequest<T> {
  /// Unique identifier for the request
  final String uuid;

  /// Type of the request
  final IsolateRequestType type;

  /// Data payload
  final T? data;

  IsolateRequest({required this.uuid, required this.type, this.data});

  /// Convert request to a map
  Map<String, dynamic> toMap() {
    return {'uuid': uuid, 'type': type, if (data != null) 'data': data};
  }

  /// Create a request from a map
  factory IsolateRequest.fromMap(Map<String, dynamic> map) {
    return IsolateRequest(uuid: map['uuid'] as String, type: map['type'], data: map['data'] as T?);
  }
}

/// A standard response format for isolate communication
class IsolateResponse<T> {
  /// Unique identifier for the request
  final String uuid;

  /// Indicates if the operation was successful
  final bool ok;

  /// Error details if ok is false
  final String? error;

  /// Optional message about the operation
  final String? message;

  /// Optional data payload
  final T? data;

  IsolateResponse({required this.uuid, required this.ok, this.error, this.message, this.data});

  /// Create a success response
  factory IsolateResponse.success({required String uuid, String? message, T? data}) {
    return IsolateResponse(uuid: uuid, ok: true, message: message, data: data);
  }

  /// Create an error response
  factory IsolateResponse.error({required String uuid, required String error, String? message}) {
    return IsolateResponse(uuid: uuid, ok: false, error: error, message: message);
  }

  /// Convert response to a map
  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'ok': ok,
      if (error != null) 'error': error,
      if (message != null) 'message': message,
      if (data != null) 'data': data,
    };
  }

  /// Create a response from a map
  factory IsolateResponse.fromMap(Map<String, dynamic> map) {
    return IsolateResponse(
      uuid: map['uuid'] as String,
      ok: map['ok'] as bool,
      error: map['error'] as String?,
      message: map['message'] as String?,
      data: map['data'] as T?,
    );
  }
}

/// Helper class to emit events from within the isolate to the main thread
class IsolateEventEmitter {
  static SendPort? _sendPort;

  /// Internal method to set the send port (called from isolate entry point)
  /// This method is public so it can be used by specialized isolate implementations
  static void setSendPort(SendPort port) {
    _sendPort = port;
  }

  /// Emit an event from the isolate to the main thread
  static void emit(IsolateEvent event, dynamic data) {
    if (_sendPort == null) {
      Logger.warn('Cannot emit event ${event.name}: SendPort not initialized');
      return;
    }

    final eventMessage = IsolateEventMessage(type: event, data: data);
    _sendPort!.send(eventMessage.toMap());
  }
}
