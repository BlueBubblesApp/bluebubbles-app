import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/env.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/interfaces/chat_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_it/get_it.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

/// Where the incoming event originated.
enum MessageSource {
  /// Received via the WebSocket connection.
  socket,

  /// Received via Android MethodChannel (FCM / Firebase push).
  methodChannel,

  /// Parsed directly from an HTTP API response.
  apiResponse,
}

/// What kind of event the server emitted.
enum MessageEventType {
  /// A message that has not been seen before.
  newMessage,

  /// An update to an already-known message (GUID swap, read-receipt, edit, …).
  updatedMessage,
}

// ─── Payload ─────────────────────────────────────────────────────────────────

/// A fully-parsed incoming message event, regardless of transport.
class IncomingPayload {
  final MessageEventType type;
  final MessageSource source;

  /// The (potentially incomplete) chat that the server included in the event.
  /// Will be hydrated before any DB write.
  final Chat chat;

  final Message message;
  final List<Attachment> attachments;

  /// The local temp GUID that was assigned when *we* sent this message.
  /// Present only when the server is echoing back one of our own sends.
  final String? tempGuid;

  const IncomingPayload({
    required this.type,
    required this.source,
    required this.chat,
    required this.message,
    this.attachments = const [],
    this.tempGuid,
  });

  IncomingPayload copyWith({
    MessageEventType? type,
    MessageSource? source,
    Chat? chat,
    Message? message,
    List<Attachment>? attachments,
    String? tempGuid,
  }) {
    return IncomingPayload(
      type: type ?? this.type,
      source: source ?? this.source,
      chat: chat ?? this.chat,
      message: message ?? this.message,
      attachments: attachments ?? this.attachments,
      tempGuid: tempGuid ?? this.tempGuid,
    );
  }
}

// ─── Internal bookkeeping ────────────────────────────────────────────────────

class _PendingUpdate {
  final IncomingPayload payload;
  final DateTime enqueued;
  Timer? expiryTimer;

  _PendingUpdate({required this.payload}) : enqueued = DateTime.now();
}

/// A single entry in [IncomingMessageHandler]'s internal FIFO queue.
class _QueueEntry {
  final IncomingPayload payload;
  final Completer<void> completer;
  _QueueEntry({required this.payload, required this.completer});
}

// ─── Singleton accessor ───────────────────────────────────────────────────────

const _tag = 'IncomingMessageHandler';

// ignore: non_constant_identifier_names
IncomingMessageHandler get IncomingMsgHandler => GetIt.I<IncomingMessageHandler>();

// ─── Handler ─────────────────────────────────────────────────────────────────

/// Processes all server-originating message events — new or updated — from
/// any source (WebSocket, FCM / MethodChannel, or an HTTP API response).
///
/// ## Responsibilities
///
/// 1. **Deduplication** — a ring-buffer of the last [_processedGuidLimit]
///    handled GUIDs prevents the same message from being processed twice when
///    the socket and FCM race each other.
///
/// 2. **Out-of-order event buffering** — an `updated-message` event that
///    arrives before its `new-message` counterpart is held in a parking map for
///    up to [_pendingUpdateTimeout].  Once the new-message is processed, the
///    parked update is flushed immediately.
///
/// 3. **Chat hydration** — fetches full participant data when the chat payload
///    is incomplete (new chat, empty handle list, participant-change event).
///
/// 4. **DB persistence** — delegates to the established Interface / Action
///    layer (`c.addMessage`, `Message.replaceMessage`,
///    `Attachment.replaceAttachmentAsync`).  Never performs raw ObjectBox writes.
///
/// 5. **UI reactivity** — drives [MessagesService] for granular [MessageState]
///    updates, and emits named events on [EventDispatcherSvc] for any other
///    widgets or services that need cross-cutting updates (chat tiles, badges,
///    etc.).
class IncomingMessageHandler {
  // ── Deduplication ───────────────────────────────────────────────────────

  /// LinkedHashSet gives O(1) lookup while preserving insertion order for
  /// oldest-first eviction when the ring-buffer limit is reached.
  final LinkedHashSet<String> _processedGuids = LinkedHashSet();
  static const int _processedGuidLimit = 100;

  // ── Out-of-order buffering ───────────────────────────────────────────────

  /// Keyed by the server-assigned (real) message GUID.
  final Map<String, _PendingUpdate> _pendingUpdates = {};
  static const Duration _pendingUpdateTimeout = Duration(seconds: 10);

  /// Hard cap on buffered pending updates.  If exceeded, the oldest entry is
  /// evicted (timer cancelled + warning) to prevent unbounded memory growth
  /// when a server sends many update events for GUIDs that never resolve.
  static const int _maxPendingUpdates = 500;

  // ── Per-GUID serial chain ────────────────────────────────────────────────

  /// Chains futures per GUID so that two concurrent deliveries for the same
  /// message (e.g. socket and FCM arriving simultaneously) are processed
  /// strictly in order rather than racing through the DB checks.
  final Map<String, Future<void>> _inflightByGuid = {};

  // ── Built-in queue ───────────────────────────────────────────────────────

  /// How many payloads may be actively processed at the same time.
  ///
  /// * Set to `1` for fully-serial, in-order processing.
  /// * Raise to `5` (default) or higher for better throughput during bursts.
  ///
  /// Changes take effect on the next [_drain] cycle (i.e., as soon as the
  /// next in-flight payload finishes).
  int maxConcurrency = 5;

  /// FIFO queue of payloads waiting for an available processing slot.
  final Queue<_QueueEntry> _incomingQueue = Queue();

  /// Number of payloads that are currently executing (occupying a slot).
  int _activeSlots = 0;

  /// Observable queue depth — useful for debug UIs or diagnostic logging.
  final RxInt queueDepth = 0.obs;

  /// Observable currently-active slot count.
  final RxInt activeConcurrency = 0.obs;

  // ── Primary entry point ─────────────────────────────────────────────────

  /// Enqueues [payload] for processing and returns a future that completes
  /// when the payload has been fully handled.
  ///
  /// This is the only public method callers need.  The payload is placed in an
  /// internal FIFO queue and dispatched as soon as a concurrency slot is free
  /// (up to [maxConcurrency] payloads run simultaneously).
  ///
  /// Same-GUID payloads are additionally serialized via [_inflightByGuid] so
  /// that two transports racing each other (socket + FCM) can never interleave
  /// DB writes for the same message.
  ///
  /// [front] — when `true`, the payload jumps to the **front** of the queue
  /// ahead of all waiting items.  Use this for user-initiated actions where an
  /// immediate response is expected (e.g. the outgoing-message echo arriving
  /// while a burst of incoming messages is already queued).  Defaults to
  /// `false` (normal back-of-queue insertion).
  Future<void> handle(IncomingPayload payload, {bool front = false}) {
    Logger.debug(
      'Enqueueing ${payload.type.name} [source=${payload.source.name}] '
      'guid=${payload.message.guid} tempGuid=${payload.tempGuid} chat=${payload.chat.guid}',
      tag: _tag,
    );
    final entry = _QueueEntry(payload: payload, completer: Completer<void>());
    if (front) {
      _incomingQueue.addFirst(entry);
    } else {
      _incomingQueue.addLast(entry);
    }
    queueDepth.value = _incomingQueue.length;
    _drain();
    return entry.completer.future;
  }

  // ── Queue drain ─────────────────────────────────────────────────────────

  /// Starts as many queued entries as concurrency slots allow.
  void _drain() {
    while (_activeSlots < maxConcurrency && _incomingQueue.isNotEmpty) {
      final entry = _incomingQueue.removeFirst();
      queueDepth.value = _incomingQueue.length;
      _activeSlots++;
      activeConcurrency.value = _activeSlots;
      _startProcessing(entry);
    }
  }

  /// Processes a single queue entry, chaining onto the per-GUID serial future
  /// so same-GUID events never race.  Frees its concurrency slot and re-drains
  /// when done.
  void _startProcessing(_QueueEntry entry) {
    final payload = entry.payload;
    final guid = payload.message.guid;

    // Chain onto any in-flight future for the same GUID.
    final previous = guid != null ? (_inflightByGuid[guid] ?? Future.value()) : Future.value();

    final next = previous.then((_) => _dispatchPayload(payload)).catchError((e, st) {
      Logger.error(
        'Unhandled error processing ${payload.type.name} for ${payload.message.guid}',
        error: e,
        trace: st,
        tag: _tag,
      );
    });

    if (guid != null) {
      _inflightByGuid[guid] = next;
      next.whenComplete(() {
        if (_inflightByGuid[guid] == next) _inflightByGuid.remove(guid);
      });
    }

    // Forward completion/error to the caller's future, then free the slot.
    next
        .then((_) => entry.completer.complete(), onError: (e, s) => entry.completer.completeError(e, s))
        .whenComplete(() {
      _activeSlots--;
      activeConcurrency.value = _activeSlots;
      _drain();
    });
  }

  Future<void> _dispatchPayload(IncomingPayload payload) async {
    switch (payload.type) {
      case MessageEventType.newMessage:
        await _processNewMessage(payload);
      case MessageEventType.updatedMessage:
        await _processUpdatedMessage(payload);
    }
  }

  // ── Service lifecycle ────────────────────────────────────────────────────

  /// Cancels all pending timers and fails any queued items so their futures
  /// don't hang indefinitely.
  ///
  /// Called automatically by GetIt when the singleton is unregistered
  /// (registered with `dispose: (svc) => svc.dispose()`).
  void dispose() {
    // Cancel all pending-update expiry timers so they don't fire after the
    // service has been destroyed.
    for (final pending in _pendingUpdates.values) {
      pending.expiryTimer?.cancel();
    }
    _pendingUpdates.clear();
    _inflightByGuid.clear();
    _processedGuids.clear();
    // Fail any payloads still waiting in the queue so their futures don't hang.
    while (_incomingQueue.isNotEmpty) {
      _incomingQueue.removeFirst().completer.completeError(
            StateError('IncomingMessageHandler disposed before payload was processed'),
          );
    }
  }

  // ── New-message pipeline ────────────────────────────────────────────────

  Future<void> _processNewMessage(IncomingPayload payload) async {
    final m = payload.message;
    final tempGuid = payload.tempGuid;
    final incomingAttachments = payload.attachments;

    Logger.debug(
      '[new-message] START guid=${m.guid} tempGuid=$tempGuid '
      'isFromMe=${m.isFromMe} chat=${payload.chat.guid} source=${payload.source.name}',
      tag: _tag,
    );

    // 1. Deduplication — skip real GUIDs we have already fully handled.
    if (m.guid != null && _hasProcessed(m.guid!)) {
      Logger.debug('[new-message] skipping already-processed ${m.guid}', tag: _tag);
      return;
    }

    // 2. If the message already exists in the DB (e.g. the HTTP response
    //    saved it before the socket event arrived, or a duplicate delivery),
    //    redirect to the updated-message pipeline for a clean GUID swap or
    //    field refresh.
    final existsByTempGuid = tempGuid != null ? Message.findOne(guid: tempGuid) : null;
    final existsByRealGuid = m.guid != null ? Message.findOne(guid: m.guid) : null;
    if (existsByTempGuid != null || existsByRealGuid != null) {
      Logger.debug('[new-message] ${m.guid} already in DB — routing to updated-message pipeline', tag: _tag);
      await _processUpdatedMessage(payload.copyWith(type: MessageEventType.updatedMessage));
      return;
    }

    // 3. Chat hydration — ensures participants and DB ID are populated.
    final hydrated = await _hydrateChat(payload.chat, m);
    Chat c = hydrated.chat;
    if (!isIsolate && hydrated.affectedHandleIds.isNotEmpty) {
      ContactsSvcV2.notifyHandlesUpdated(hydrated.affectedHandleIds);
    }

    // 4. Persist to DB.
    //    Only suppress the "from me" notification clear for reactions so that a
    //    notification-triggered reaction doesn't lose its source notification.
    final clearNotificationFromMe = (m.isFromMe ?? false) && m.associatedMessageGuid == null;
    final result = await c.addMessage(
      m,
      clearNotificationsIfFromMe: clearNotificationFromMe,
      attachments: incomingAttachments,
    );
    final saved = result.message;

    // 5. Mark as processed before any async I/O so a duplicate delivery that
    //    races in while we're playing a sound or sending a notification skips.
    if (saved.guid != null) _markProcessed(saved.guid!);

    // 6. Complete any pending outgoing send-progress tracker.
    if (tempGuid != null && GetIt.I.isRegistered<OutgoingMessageHandler>()) {
      OutgoingMsgHandler.completeSendProgressIfExists(tempGuid, Origin.incomingMessageHandler);
    }

    // 7. Audible receive feedback.
    //    The original ActionHandler gates sound on its shouldNotifyForNewMessageGuid dedup flag.
    //    Here, dedup already short-circuited at step 1, so we just gate on isFromMe:
    //    outgoing echoes never need a receive sound; real incoming messages do.
    if (!(saved.isFromMe ?? false)) await _playReceiveSound();

    // 8. Drive UI reactivity, if not in a background isolate.
    if (!isIsolate) {
      unawaited(_dispatchNewMessage(c, saved, tempGuid: tempGuid));

      // 10. Refresh chat-list ordering and subtitle.

      // Guard: addMessage() may have set hasUnreadMessage = true in the DB even
      // when this chat is the one currently open.  Clear it on the in-memory
      // object before propagating to the UI so the badge never increments for
      // the active chat, then persist the read state asynchronously.
      if (ChatsSvc.isChatActive(c.guid)) {
        c.hasUnreadMessage = false;
        unawaited(ChatsSvc.setChatHasUnread(c, false, force: true));
      }

      // The latest message is linked on the guarded sync path (Chat.addMessage,
      // gated on isNewer), so a freshly-added chat's tile already has its subtitle
      // on first paint here.
      //
      // Gate add-vs-update on the chat actually existing, not on updateChat's return:
      // updateChat also returns false when headless or when the chat's state isn't
      // loaded, which would otherwise call addChat for a chat that already exists.
      if (ChatsSvc.findChatByGuid(c.guid) != null) {
        ChatsSvc.updateChat(c, override: true);
      } else {
        await ChatsSvc.addChat(c, immediate: true);
      }
      ChatsSvc.updateChatLatestMessage(c.guid, saved);

      // Fire after the ChatState exists (addChat above) so a contact link
      // resolved during hydration isn't dropped by ChatsService.updateChat's
      // no-op-when-no-state-yet guard for a chat that's brand new this call.
      if (hydrated.affectedHandleIds.isNotEmpty) {
        ContactsSvcV2.notifyHandlesUpdated(hydrated.affectedHandleIds);
      }
    }

    // 9. Push / in-app notification.
    // Must be awaited: the notification pipeline posts a MethodChannel call back
    // to Android. Without await, the DartWorker engine can be destroyed before
    // that call fires, silently dropping the notification.
    if (GetIt.I.isRegistered<NotificationsService>()) {
      await GetIt.I.isReady<NotificationsService>();
      await NotificationsSvc.tryCreateNewMessageNotification(saved, c);
    } else {
      Logger.warn(
        'NotificationsService not registered yet; skipping notification for ${saved.guid}',
        tag: _tag,
      );
    }

    // 10.5. Group photo changes — fetch/clear icon from server now that the
    //       message is safely in the DB.  This runs regardless of isolate mode
    //       because Chat.getIcon persists to DB; the state update is guarded.
    if (saved.isGroupPhotoEvent) {
      if (saved.isGroupPhotoRemoved) {
        // Photo explicitly removed.
        if (!isIsolate) {
          unawaited(ChatsSvc.setChatCustomAvatarPath(c, null));
        } else {
          c.customAvatarPath = null;
          unawaited(c.saveAsync(updateCustomAvatarPath: true));
        }
      } else {
        // Photo added or changed — pull from server.
        unawaited(Chat.getIcon(c, force: true).then((_) {
          if (!isIsolate) ChatsSvc.updateChat(c, override: true);
        }));
      }
    }

    // 11. Flush any out-of-order updated-message that arrived before us.
    if (saved.guid != null) _flushPendingUpdate(saved.guid!, c);
  }

  // ── Updated-message pipeline ────────────────────────────────────────────

  Future<void> _processUpdatedMessage(IncomingPayload payload) async {
    final m = payload.message;
    final tempGuid = payload.tempGuid;
    final replacementAttachments = List<Attachment?>.from(payload.attachments);

    Logger.debug(
      '[updated-message] START guid=${m.guid} tempGuid=$tempGuid '
      'isFromMe=${m.isFromMe} chat=${payload.chat.guid} source=${payload.source.name}',
      tag: _tag,
    );

    // 1. Complete any pending send-progress tracker first.
    if (tempGuid != null && GetIt.I.isRegistered<OutgoingMessageHandler>()) {
      OutgoingMsgHandler.completeSendProgressIfExists(tempGuid, Origin.incomingMessageHandler);
    }

    // 2. Locate the existing DB record.
    //    Try tempGuid first (outgoing echo), then fall back to the real GUID
    //    (read-receipt, edit, or a re-delivery of an already-saved message).
    Message? existing;
    if (tempGuid != null) existing = Message.findOne(guid: tempGuid);
    if (existing == null && m.guid != null) existing = Message.findOne(guid: m.guid);

    // 3. Out-of-order buffering.
    //    The new-message event hasn't arrived yet — park this payload and
    //    wait.  _flushPendingUpdate will re-invoke this method once the
    //    new-message is processed.
    if (existing == null) {
      Logger.info(
        'updated-message for ${m.guid} has no DB record yet — buffering',
        tag: _tag,
      );
      await _parkPendingUpdate(payload);
      return;
    }

    // 4. Chat hydration.
    final hydrated = await _hydrateChat(payload.chat, m);
    Chat c = hydrated.chat;
    if (!isIsolate && hydrated.affectedHandleIds.isNotEmpty) {
      ContactsSvcV2.notifyHandlesUpdated(hydrated.affectedHandleIds);
    }

    // 5. Persist the GUID swap / field update.
    final existingGuid = tempGuid ?? existing.guid!;
    await _replaceMessage(c, existingGuid, existing, m);

    // 6. Persist attachment GUID swaps (e.g. temp attachment → real GUID).
    await _replaceAttachments(c, existingGuid, existing, m, replacementAttachments);

    // 7. Drive UI reactivity, if not in a background isolate.
    if (!isIsolate) {
      _dispatchUpdatedMessage(c, m, oldGuid: tempGuid);

      // 8. Refresh chat-list ordering and subtitle (only if this message is the latest).
      ChatsSvc.updateChat(c, override: true);
      final chatState = ChatsSvc.getChatState(c.guid);
      if (chatState != null && chatState.latestMessage.value?.guid == m.guid) {
        ChatsSvc.updateChatLatestMessage(c.guid, m);
      }
    }
  }

  // ── Chat hydration ──────────────────────────────────────────────────────

  /// Returns a fully-hydrated [Chat] object with handle/participant data, plus the IDs
  /// of any handles that were brand-new and just got a [ContactV2] linked to them.
  ///
  /// Strategy (in priority order):
  /// 1. Participant-change events (e.g. add/remove member) always force a
  ///    fresh server fetch because the local record is about to be stale.
  /// 2. When the chat is already in the local DB *and* has participants,
  ///    return it directly — no network round-trip needed.
  /// 3. When the chat is in the DB but participants are missing, re-fetch
  ///    from the server to populate them.
  /// 4. When the chat isn't in the DB at all, sync it via [ChatInterface].
  Future<({Chat chat, List<int> affectedHandleIds})> _hydrateChat(Chat partial, Message m) async {
    // Group events always need fresh server data.
    if (m.isGroupEvent) {
      partial = (await ChatsSvc.fetchChat(partial.guid)) ?? partial;
    } else {
      // If we have a local copy and the local copy has participants, use it — no need to fetch.
      final local = Chat.findOne(guid: partial.guid);
      if (local != null && local.handles.isNotEmpty) {
        return (chat: local, affectedHandleIds: <int>[]);
        // Cases to fetch from the server:
        // * Local chat exists but has no participants (incomplete data).
        // * Local chat doesn't exist at all (new chat).
      } else if ((local != null && local.handles.isEmpty) || local == null) {
        partial = (await ChatsSvc.fetchChat(partial.guid)) ?? partial;
      }
    }

    // Chat isn't in the local DB yet — sync it from the server.
    final result = await ChatInterface.bulkSyncChats(chatsData: [partial.toMap()]);
    final synced = result.chats.firstOrNull ?? partial;
    if (synced.id == null) {
      Logger.warn('Failed to sync new chat ${partial.guid} for message ${m.guid}', tag: _tag);
    }
    return (chat: synced, affectedHandleIds: result.affectedHandleIds);
  }

  // ── DB helpers ──────────────────────────────────────────────────────────

  /// Replaces [existingGuid] with [replacement] in the messages table.
  ///
  /// Handles the case where a parallel delivery path (e.g. HTTP response +
  /// socket) has already written [replacement.guid] to the DB.
  Future<void> _replaceMessage(
    Chat chat,
    String existingGuid,
    Message existing,
    Message replacement,
  ) async {
    final alreadyPresent = Message.findOne(guid: replacement.guid);

    if (alreadyPresent != null) {
      // The replacement record already exists (parallel delivery).
      // Only overwrite if the incoming payload is newer.
      if (replacement.isNewerThan(alreadyPresent)) {
        await Message.replaceMessage(replacement.guid, replacement);
      }

      // Clean up the stale temp record when the real one is now present.
      if (existingGuid != replacement.guid) {
        final stale = Message.findOne(guid: existingGuid);
        if (stale != null) Message.delete(stale.guid!);
      }
    } else {
      try {
        await Message.replaceMessage(existingGuid, replacement);
      } catch (ex, st) {
        Logger.warn(
          '[_replaceMessage] failed: $existingGuid → ${replacement.guid}',
          error: ex,
          trace: st,
          tag: _tag,
        );
      }
    }
  }

  /// Swaps attachment GUIDs on the replacement message's attachments.
  ///
  /// ### Why this is needed
  ///
  /// When an attachment is sent, the local attachment record is created with
  /// the same temp GUID as its parent message (`temp-XXXXXXXX`).  The server
  /// then assigns a real GUID.  This method resolves which local GUID to
  /// replace by index, using the following priority:
  ///
  /// * If [existingGuid] starts with `temp-`, it was the attachment GUID
  ///   (they are set equal at send time in `send_animation.dart`).
  /// * Otherwise look up the DB GUID via [existing.dbAttachments] by index —
  ///   this handles socket events that omit `tempGuid` (e.g. keyboard GIFs).
  ///
  /// ### Parallel-delivery
  ///
  /// If the real attachment GUID is already in the DB (because two delivery
  /// paths raced — e.g. HTTP response and socket both arrived), the existing
  /// real record is updated in place and the stale temp record is deleted.
  Future<void> _replaceAttachments(
    Chat chat,
    String existingGuid,
    Message existing,
    Message replacement,
    List<Attachment?> replacementAttachments,
  ) async {
    for (int i = 0; i < replacementAttachments.length; i++) {
      final newAttachment = replacementAttachments[i];
      if (newAttachment == null) continue;

      // Resolve which local GUID currently owns this attachment slot.
      final String attachmentExistingGuid;
      if (existingGuid.startsWith('temp-')) {
        attachmentExistingGuid = existingGuid;
      } else if (existing.dbAttachments.isNotEmpty && i < existing.dbAttachments.length) {
        attachmentExistingGuid = existing.dbAttachments[i].guid ?? existingGuid;
      } else {
        attachmentExistingGuid = existingGuid;
      }

      try {
        // Parallel-delivery check: if the real GUID is already in the DB
        // (HTTP response saved it while socket event was in-flight), update
        // that record and clean up the stale temp attachment.
        final alreadyPresent = await Attachment.findOneAsync(newAttachment.guid!);
        if (alreadyPresent != null) {
          await Attachment.replaceAttachmentAsync(newAttachment.guid, newAttachment);

          // Delete the stale temp record if it's distinct from the real one.
          if (attachmentExistingGuid != newAttachment.guid) {
            final staleTemp = await Attachment.findOneAsync(attachmentExistingGuid);
            if (staleTemp != null) await Attachment.deleteAsync(staleTemp.guid!);
          }
        } else {
          // Normal path: rename the temp attachment to the real GUID.
          await Attachment.replaceAttachmentAsync(attachmentExistingGuid, newAttachment);

          // Rename the AttachmentState so UI listeners get the real GUID.
          if (attachmentExistingGuid != newAttachment.guid && Get.isRegistered<MessagesService>(tag: chat.guid)) {
            // Complete the attachment state at the temp key WITHOUT renaming the
            // map key.  The widget finds the state via part.attachments.first.guid
            // (always the temp GUID) so it must remain discoverable while its Obx
            // is live.  _syncAttachmentStates promotes the key to the real GUID
            // once updateMessage updates the message struct.
            MessagesSvc(chat.guid)
                .notifyAttachmentSendComplete(existingGuid, replacement.guid!, attachmentExistingGuid, newAttachment);
          }
        }
        // MessagesService is notified once by _dispatchUpdatedMessage after all
        // attachments are processed — calling it per-attachment would cause N
        // unnecessary intermediate redraws.
      } catch (ex, st) {
        Logger.warn(
          '[_replaceAttachments] failed: $attachmentExistingGuid → ${newAttachment.guid}',
          error: ex,
          trace: st,
          tag: _tag,
        );
      }
    }

    // After all DB swaps complete, notify MessagesService so the MessageState
    // for this message gets the updated attachment list (real GUIDs replacing temp ones).
    if (replacementAttachments.isNotEmpty && Get.isRegistered<MessagesService>(tag: chat.guid)) {
      // Re-fetch from DB so the attachment relations reflect the post-swap state.
      final freshMessage = Message.findOne(guid: replacement.guid!);
      if (freshMessage != null) {
        MessagesSvc(chat.guid).updateMessage(
          freshMessage,
          oldGuid: existingGuid != freshMessage.guid ? existingGuid : null,
        );
      } else {
        Logger.warn(
          '[_replaceAttachments] could not reload message ${replacement.guid} from DB for MessagesService update',
          tag: _tag,
        );
      }
    }
  }

  // ── UI dispatch ─────────────────────────────────────────────────────────

  /// Notifies the UI layer about a newly-received or newly-saved message.
  ///
  /// For *outgoing* messages echoed back from the server (i.e. [tempGuid] is
  /// set), [MessagesService.updateMessage] is called explicitly with the old
  /// GUID so the temp bubble transitions to its final state.
  ///
  /// For *incoming* messages from other participants, [MessagesService.addNewMessage]
  /// is called explicitly so the message enters the view immediately without
  /// relying on the ObjectBox DB watch.
  ///
  /// An `EventDispatcherSvc.emit` is fired in both cases so chat tiles, badge
  /// counts, and any other cross-cutting listeners can react.
  Future<void> _dispatchNewMessage(Chat chat, Message message, {String? tempGuid}) async {
    final msvcRegistered = Get.isRegistered<MessagesService>(tag: chat.guid);
    // A tempGuid in the payload means this was an outgoing send from *some*
    // BlueBubbles client, but not necessarily *this* device.  Only treat it as
    // a GUID swap (updateMessage) if the temp entry is already known to this
    // device's MessagesService.  If it isn't (sent from another client), fall
    // through and add it as a new message instead.
    final svc = msvcRegistered ? MessagesSvc(chat.guid) : null;
    final tempExistsLocally = tempGuid != null && svc != null && svc.struct.getMessage(tempGuid) != null;
    final realExistsLocally = message.guid != null && svc != null && svc.struct.getMessage(message.guid!) != null;

    if (tempExistsLocally) {
      // Our outgoing message echoed back — swap the temp bubble in-place.
      svc.updateMessage(message, oldGuid: tempGuid);
    } else if (realExistsLocally) {
      // Real GUID already present (e.g. a prior event already inserted it),
      // refresh fields in-place without duplicating.
      svc.updateMessage(message);
    } else if (svc != null) {
      // Pure incoming message (or sent from another device), push it into the
      // active chat view explicitly.
      if (tempGuid != null) {
        Logger.debug('[_dispatchNewMessage] tempGuid=$tempGuid not in local struct — treating as new message',
            tag: _tag);
      }
      await svc.addNewMessage(message);
    }

    EventDispatcherSvc.emit('new-message', {
      'chatGuid': chat.guid,
      'message': message,
    });
  }

  /// Notifies the UI layer about an update to an existing message.
  void _dispatchUpdatedMessage(Chat chat, Message message, {String? oldGuid}) {
    if (Get.isRegistered<MessagesService>(tag: chat.guid)) {
      MessagesSvc(chat.guid).updateMessage(message, oldGuid: oldGuid);
    }

    EventDispatcherSvc.emit('updated-message', {
      'chatGuid': chat.guid,
      'message': message,
      'oldGuid': oldGuid,
    });
  }

  // ── Out-of-order buffering ──────────────────────────────────────────────

  /// Parks an [IncomingPayload] whose DB record doesn't exist yet.
  ///
  /// Before parking, a final DB lookup is performed to guard against a race
  /// where the new-message was written between the check in
  /// [_processUpdatedMessage] and this call — in that case the payload is
  /// processed immediately instead of being buffered.
  ///
  /// If a pending update for the same GUID already exists (i.e. the server
  /// emitted more than one `updated-message` before the `new-message`), the
  /// existing entry is replaced with the newest payload, since the latest event
  /// always carries the most up-to-date data.  The expiry timer is reset so the
  /// fresh update gets its own full timeout window.
  ///
  /// If no matching new-message arrives within [_pendingUpdateTimeout], the
  /// parked payload is discarded with a warning.
  Future<void> _parkPendingUpdate(IncomingPayload payload) async {
    final guid = payload.message.guid;
    if (guid == null) return;

    // Final safety check: re-query the DB in case the new-message landed
    // between the check in _processUpdatedMessage and now.
    final raceCheck = Message.findOne(guid: guid);
    if (raceCheck != null) {
      Logger.debug(
        'Race resolved: $guid appeared in DB before parking — processing immediately',
        tag: _tag,
      );
      await _processUpdatedMessage(payload);
      return;
    }

    // If we already have a pending update for this GUID, cancel its timer and
    // replace the payload with the newer one.
    final existing = _pendingUpdates[guid];
    if (existing != null) {
      existing.expiryTimer?.cancel();
      Logger.debug(
        'Replacing buffered update for $guid with newer payload',
        tag: _tag,
      );
    }

    // Evict the oldest pending update if we've hit the hard cap.
    if (_pendingUpdates.length >= _maxPendingUpdates && !_pendingUpdates.containsKey(guid)) {
      final oldestGuid = _pendingUpdates.keys.first;
      final oldest = _pendingUpdates.remove(oldestGuid)!;
      oldest.expiryTimer?.cancel();
      Logger.warn(
        'Pending-update buffer full ($_maxPendingUpdates) — evicting oldest entry $oldestGuid, processing anyway',
        tag: _tag,
      );
      unawaited(handle(oldest.payload, front: true).catchError((e, st) {
        Logger.warn(
          'Failed to process evicted buffered update for $oldestGuid',
          error: e,
          trace: st,
          tag: _tag,
        );
      }));
    }

    final pending = _PendingUpdate(payload: payload);
    pending.expiryTimer = Timer(_pendingUpdateTimeout, () {
      final expired = _pendingUpdates.remove(guid);
      if (expired != null) {
        Logger.warn(
          'Buffered update for $guid expired after ${_pendingUpdateTimeout.inSeconds}s '
          'without a matching new-message — processing anyway',
          tag: _tag,
        );
        unawaited(handle(expired.payload, front: true).catchError((e, st) {
          Logger.warn(
            'Failed to process expired buffered update for $guid',
            error: e,
            trace: st,
            tag: _tag,
          );
        }));
      }
    });
    _pendingUpdates[guid] = pending;
  }

  /// Drains the parked update for [messageGuid], if one exists.
  ///
  /// Called at the end of [_processNewMessage] so that any update
  /// which raced ahead is applied immediately after the message is saved.
  void _flushPendingUpdate(String messageGuid, Chat chat) {
    final pending = _pendingUpdates.remove(messageGuid);
    if (pending == null) return;

    pending.expiryTimer?.cancel();
    Logger.debug('Flushing buffered update for $messageGuid', tag: _tag);

    // Route through the normal queue (front: true so it's next up) rather than
    // calling _processUpdatedMessage directly.  This ensures the flushed update
    // chains onto the per-GUID _inflightByGuid future, preventing a race with
    // any same-GUID event already waiting in the queue behind the new-message.
    unawaited(handle(pending.payload, front: true).catchError((e, st) {
      Logger.warn(
        'Failed to flush buffered update for $messageGuid',
        error: e,
        trace: st,
        tag: _tag,
      );
    }));
  }

  // ── Deduplication helpers ────────────────────────────────────────────────

  bool _hasProcessed(String guid) => _processedGuids.contains(guid);

  void _markProcessed(String guid) {
    if (_processedGuids.contains(guid)) return;
    _processedGuids.add(guid);
    // Evict oldest entries when the ring-buffer limit is reached.
    while (_processedGuids.length > _processedGuidLimit) {
      _processedGuids.remove(_processedGuids.first);
    }
  }

  // ── Receive sound ────────────────────────────────────────────────────────

  /// Plays the configured receive sound, mirroring the original ActionHandler behaviour:
  /// * Android: only while the app process is alive, so headless wake-ups do not play audio.
  /// * Desktop: may play regardless of window focus.
  Future<void> _playReceiveSound() async {
    if (SettingsSvc.settings.receiveSoundPath.value == null) return;
    if (SettingsSvc.settings.soundVolume.value == 0) return;
    if (Platform.isAndroid && !LifecycleSvc.isAlive) return;

    if (kIsDesktop) {
      final player = Player();
      player.stream.completed
          .firstWhere((done) => done)
          .then((_) => Future.delayed(const Duration(milliseconds: 500), player.dispose));
      await player.setVolume(SettingsSvc.settings.soundVolume.value.toDouble());
      await player.open(Media(SettingsSvc.settings.receiveSoundPath.value!));
    } else if (!kIsWeb) {
      final controller = PlayerController();
      await controller.preparePlayer(
        path: SettingsSvc.settings.receiveSoundPath.value!,
        volume: SettingsSvc.settings.soundVolume.value / 100,
      );
      await controller.startPlayer();
      // Dispose the controller once playback finishes to avoid leaking native
      // audio resources.  Uses onCompletion (Stream<void>) rather than
      // onPlayerStateChanged so we don't need to reference PlayerState, which
      // is defined in both audio_waveforms and media_kit.
      unawaited(
        controller.onCompletion.first.whenComplete(controller.dispose).catchError((Object _) {}),
      );
    }
  }
}
