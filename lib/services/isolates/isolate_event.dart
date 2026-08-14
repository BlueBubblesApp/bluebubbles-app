/// Enum representing events that can be emitted from the isolate to the main thread
///
/// Usage from main thread:
/// ```dart
/// // Register a listener
/// GetIt.I<GlobalIsolate>().addEventListener(IsolateEvent.socketMessage, (data) {
///   print('Socket message received: $data');
/// });
///
/// // Remove a specific listener
/// GetIt.I<GlobalIsolate>().removeEventListener(IsolateEvent.socketMessage, myListener);
///
/// // Clear all listeners for an event
/// GetIt.I<GlobalIsolate>().removeAllEventListeners(IsolateEvent.socketMessage);
///
/// // Clear all listeners
/// GetIt.I<GlobalIsolate>().clearAllEventListeners();
///
/// // Close the isolate and clear listeners
/// GetIt.I<GlobalIsolate>().close();
/// ```
///
/// Usage from isolate thread:
/// ```dart
/// // Emit an event to the main thread
/// IsolateEventEmitter.emit(IsolateEvent.socketMessage, {'message': 'Hello from isolate!'});
/// ```
enum IsolateEvent {
  /// Socket message received from server
  socketMessage,

  /// Attachment upload progress emitted from the isolate
  attachmentUploadProgress,

  /// Emitted after each page of messages is persisted during incremental sync.
  /// Payload: `Map<String, dynamic>` with keys:
  ///   `messageIdsByChat`       — `Map<String, List<int>>` chatGuid → DB IDs saved in this page
  ///   `latestMessageIdPerChat` — `Map<String, int>` chatGuid → latest message DB ID in this page
  incrementalSyncPageComplete,

  /// Emitted periodically while a storage analysis walks the attachments directory.
  /// Payload: `Map<String, dynamic>` with keys:
  ///   `runId`     — `String` opaque id of the analysis run this update belongs to
  ///   `stage`     — `String` name of a `StorageAnalysisStage` value
  ///   `processed` — `int` units finished within the current stage
  ///   `total`     — `int` total units in the current stage (0 when indeterminate)
  ///   `bytes`     — `int` bytes measured so far, for a live-updating total
  storageAnalysisProgress,
}

/// A standard event message format for isolate-to-main communication
class IsolateEventMessage<T> {
  /// Type of the event
  final IsolateEvent type;

  /// Data payload
  final T? data;

  IsolateEventMessage({required this.type, this.data});

  /// Convert event to a map
  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'event': type.name,
      if (data != null) 'data': data,
    };
  }

  /// Create an event from a map
  factory IsolateEventMessage.fromMap(Map<String, dynamic> map) {
    final eventName = map['event'] as String;
    final type = IsolateEvent.values.firstWhere(
      (e) => e.name == eventName,
      orElse: () => throw Exception('Unknown event type: $eventName'),
    );
    return IsolateEventMessage(
      type: type,
      data: map['data'] as T?,
    );
  }
}
