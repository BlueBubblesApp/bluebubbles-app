import 'package:bluebubbles/models/models.dart' show AttachmentUploadProgress;
import 'dart:async';
import 'dart:collection';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/interfaces/send_message_interface.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/file_utils.dart';
import 'package:path/path.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:get_it/get_it.dart';
import 'package:universal_io/io.dart';

// ─── Singleton accessor ───────────────────────────────────────────────────────

const _tag = 'OutgoingMessageHandler';

/// Outgoing-prep retry policy: retry a transient prep failure up to
/// [_maxPrepAttempts] times, backing off [_retryBackoffMs] ms times the attempt.
const _maxPrepAttempts = 3;
const _retryBackoffMs = 250;

// ignore: non_constant_identifier_names
OutgoingMessageHandler get OutgoingMsgHandler => GetIt.I<OutgoingMessageHandler>();

// ─── Internal queue entry ─────────────────────────────────────────────────────

class _OutgoingEntry {
  final OutgoingQueueItem item;

  _OutgoingEntry(this.item);
}

// ─── Handler ─────────────────────────────────────────────────────────────────

/// Processes all outgoing message events — text, multipart, and attachments.
///
/// ## Responsibilities
///
/// 1. **Serial send queue** — all sends are queued and processed one at a time
///    so messages always arrive in the order the user sent them.
///
/// 2. **Pre-send preparation** — `_buildOutgoingMessages` / `_persistOutgoingMessages`
///    / `prepAttachment` write the temp message/attachment to the DB and the
///    MessagesService *before* the HTTP call is made, so the UI shows the
///    outgoing bubble immediately.
///
/// 3. **GUID replacement** — when the HTTP response arrives with the server's
///    real GUID, replaces the temp record in the DB and notifies [MessagesService]
///    so the bubble transitions from the temp ID to the permanent one.
///
/// 4. **Send-progress coordination** — exposes [completeSendProgressIfExists]
///    so [IncomingMessageHandler] can complete a send-progress tracker early
///    when a socket event for our own message arrives before the HTTP response.
///
/// 5. **Error marking** — failed sends update the message's GUID and error code
///    so the UI can show a retry/error badge.
class _SendProgressTracker {
  final Chat chat;
  final Completer<void> completer;

  _SendProgressTracker(this.chat, this.completer);
}

class OutgoingMessageHandler {
  OutgoingMessageHandler() {
    if (GetIt.I.isRegistered<GlobalIsolate>()) {
      GetIt.I<GlobalIsolate>()
          .addEventListener(IsolateEvent.attachmentUploadProgress, _handleAttachmentUploadProgressEvent);
    }
  }

  // ── Attachment upload progress ───────────────────────────────────────────

  /// Observable list of (attachmentGuid, uploadProgress) pairs.
  /// Read by [AttachmentsService] to drive progress indicators in the UI.
  final RxList<AttachmentUploadProgress> attachmentProgress = <AttachmentUploadProgress>[].obs;

  /// The active [CancelToken] for the most-recently-started attachment upload.
  /// The UI cancels this when the user presses the cancel button in the
  /// attachment bubble.
  CancelToken? latestCancelToken;

  void _handleAttachmentUploadProgressEvent(dynamic data) {
    if (data is! Map<String, dynamic>) return;

    final chatGuid = data['chatGuid'] as String?;
    final messageGuid = data['messageGuid'] as String?;
    final rawProgress = data['progress'];
    final progress = rawProgress is num ? rawProgress.toDouble().clamp(0.0, 1.0) : null;

    if (chatGuid == null || messageGuid == null || progress == null) {
      Logger.warn('Ignoring malformed attachment upload progress event: $data', tag: _tag);
      return;
    }

    final inFlight = attachmentProgress.firstWhereOrNull((entry) => entry.guid == messageGuid);
    if (inFlight != null) {
      inFlight.progress.value = progress;
    } else {
      attachmentProgress.add(AttachmentUploadProgress(messageGuid, progress.obs));
    }

    if (Get.isRegistered<MessagesService>(tag: chatGuid)) {
      MessagesSvc(chatGuid).notifyAttachmentUploadProgress(messageGuid, messageGuid, progress);
    }
  }

  // ── Send-progress trackers ───────────────────────────────────────────────

  /// tempGuid → (Chat, Completer) for the in-flight send futures.
  ///
  /// Allows [IncomingMessageHandler] to complete a send early when a socket
  /// event echoing our own message arrives before the HTTP response.
  final Map<String, _SendProgressTracker> _sendProgressTrackers = {};

  /// Registers a tracker so that [completeSendProgressIfExists] can complete
  /// [completer] and update [chat.sendProgress] if the socket event wins the
  /// HTTP vs. socket race.
  void registerSendProgressTracker(String tempGuid, Chat chat, Completer<void> completer) {
    _sendProgressTrackers[tempGuid] = _SendProgressTracker(chat, completer);
  }

  /// Called by [IncomingMessageHandler] when it receives a socket event for a
  /// message we just sent (i.e. [tempGuid] is in the tracker map).
  ///
  /// Completes the registered completer early and drives the progress
  /// animation to its final state so the UI doesn't wait for the HTTP
  /// response.
  void completeSendProgressIfExists(
    String tempGuid,
    Origin origin, {
    Object? error,
    StackTrace? stack,
  }) {
    final tracker = _sendProgressTrackers.remove(tempGuid);
    if (tracker == null) return;

    if (origin == Origin.incomingMessageHandler) {
    } else if (origin == Origin.outgoingMessageHandler) {
    } else {
      Logger.warn('Unknown origin $origin for send progress completion of $tempGuid', tag: _tag);
    }

    final chat = tracker.chat;
    final completer = tracker.completer;
    if (chat.sendProgress.value != 0) {
      chat.sendProgress.value = 1;
      Timer(const Duration(milliseconds: 500), () {
        chat.sendProgress.value = 0;
      });
    }
    if (!completer.isCompleted) {
      if (error != null) {
        completer.completeError(error, stack);
      } else {
        completer.complete();
      }
    }
  }

  // ── Serial outgoing queue ────────────────────────────────────────────────

  final Queue<_OutgoingEntry> _queue = Queue();
  bool _isProcessing = false;

  /// Reactive set of chat GUIDs that currently have one or more items waiting
  /// in the queue.  Widgets can wrap reads of this inside [Obx] to show or
  /// hide UI controls (e.g. a "Cancel Outgoing Messages" action) only when
  /// there is actually something pending for a given chat.
  final pendingChatGuids = <String>{}.obs;

  /// Enqueues [item] for sending.  Preparation (DB write / file copy) is
  /// performed synchronously before the item enters the queue, so the
  /// outgoing bubble appears in the UI immediately.  The actual HTTP call
  /// happens when the queue reaches this item.
  ///
  /// Returns a [Future] that completes (or errors) when the item's
  /// [OutgoingQueueItem.completer] resolves — i.e. when the HTTP response arrives
  /// or an error is surfaced.
  Future<void> queue(OutgoingQueueItem item) async {
    // Every item must have a stable temp GUID before prep/retry begins — see
    // [_ensureTempGuid]. Centralized here so individual UI call sites can't
    // forget it (several did, historically — that's what caused this to be
    // centralized rather than left to convention).
    _ensureTempGuid(item);

    // Prep the item (writes temp messages / copies attachment files to disk),
    // retrying a transient failure and surfacing a terminal one as a failed
    // message so it is never silently dropped. See [_prepItemWithRetry].
    final prep = await _prepItemWithRetry(item);
    if (!prep.ok) return;
    final returned = prep.result;

    if (returned is List<Message>) {
      // _persistOutgoingMessages already saved each message to the DB; create a queue
      // entry for each one with the message that was actually saved.
      for (final m in returned) {
        _queue.add(_OutgoingEntry(_copyWithMessage(item, m)));
      }
    } else {
      // Attachment: prepAttachment already saved it; keep the original item.
      _queue.add(_OutgoingEntry(item));
    }

    pendingChatGuids.add(item.chat.guid);
    unawaited(_processNext());
  }

  /// Ensures [item.message] has a stable temp GUID before prep/retry begins.
  ///
  /// A no-op if the caller (or a retry-flow like `retryFailedMessage`, which
  /// reuses the original failed message's GUID) already set one. Centralizing
  /// this here — rather than trusting every UI call site to call
  /// `generateTempGuid()` itself — is deliberate: several call sites forgot to,
  /// which crashed [_prepItemWithRetry]'s old null-check assertion.
  void _ensureTempGuid(OutgoingQueueItem item) {
    if (item.message.guid == null) item.message.generateTempGuid();
    if (item is OutgoingAttachment) item.attachment.guid = item.message.guid;
  }

  /// Prep [item] with a bounded retry on transient failure.
  ///
  /// The prep phase writes the temp record via the GlobalIsolate, which can
  /// throw if the isolate is mid-restart. If that escaped [queue] (usually a
  /// fire-and-forget call) the message would be *silently dropped* — never
  /// queued, sent, nor marked failed. So retry a transient failure, then surface
  /// a terminal one as a failed message that is visible + retryable.
  ///
  /// The message object(s) this item resolves to are built exactly ONCE (via
  /// [_buildOutgoingMessages]) before any retry attempt, so every attempt
  /// retries persistence of the *same* GUID(s) — this is what makes the
  /// "already saved?" dedup check below sound (previously, `prepMessage`
  /// regenerated the GUID on every attempt, which desynced it from the GUID
  /// this loop was checking, so retries could silently duplicate a message).
  ///
  /// Returns `(ok: true, result: <prep output>)` on success — result is a
  /// `List<Message>` for messages and `null` for attachments — or
  /// `(ok: false, ...)` once a terminal failure has been finalized (the caller
  /// should stop).
  Future<({bool ok, dynamic result})> _prepItemWithRetry(OutgoingQueueItem item) async {
    final isAttachment = item is OutgoingAttachment;

    List<Message>? built;
    if (!isAttachment) {
      built = _buildOutgoingMessages(item.chat, item.message, item.reaction, isRetry: item.isRetry);
      if (built.isEmpty) return (ok: true, result: <Message>[]);
    }

    Object? lastError;
    StackTrace? lastStack;
    int attempts = 0;
    for (int attempt = 1; attempt <= _maxPrepAttempts; attempt++) {
      attempts = attempt;
      try {
        if (isAttachment) {
          await prepAttachment(item.chat, item.message, item.attachment);
          return (ok: true, result: null);
        } else {
          return (
            ok: true,
            result: await _persistOutgoingMessages(
              item.chat,
              built!,
              item.reaction,
              clearNotificationsIfFromMe: item.clearNotificationsIfFromMe,
            ),
          );
        }
      } catch (ex, st) {
        lastError = ex;
        lastStack = st;
        // Only retry while at least one unit of work (the single message, the
        // attachment, or one of the up-to-2 split messages) is still unsaved.
        final stillUnsaved = isAttachment
            ? Message.findOne(guid: item.message.guid) == null
            : built!.any((m) => Message.findOne(guid: m.guid) == null);
        if (!stillUnsaved || attempt >= _maxPrepAttempts) break;
        Logger.warn('Outgoing prep attempt $attempt failed; retrying', error: ex, trace: st, tag: _tag);
        await Future.delayed(Duration(milliseconds: _retryBackoffMs * attempt));
      }
    }

    // Retries exhausted (or nothing left unsaved to retry): surface the
    // failure(s) as failed messages so they're visible + retryable rather than
    // silently dropped. For a split send, both halves are failed together —
    // it's one logical send, so a half-sent result would be confusing and
    // would strand the successful half in "sending" state forever (queue()
    // only enqueues what this function returns).
    final toFail = isAttachment ? [item.message] : built!;
    for (final m in toFail) {
      await _finalizeOutgoingFailure(
        item.chat,
        m,
        m.guid!,
        logMessage: 'Failed to prepare outgoing message after $attempts attempt(s)',
        error: lastError,
        stack: lastStack,
      );
    }
    item.completer?.completeError(lastError ?? StateError('Outgoing prep failed'));
    return (ok: false, result: null);
  }

  OutgoingQueueItem _copyWithMessage(OutgoingQueueItem item, Message message) {
    if (item is OutgoingReaction) {
      return OutgoingReaction(
        chat: item.chat,
        message: message,
        selectedMessage: item.selectedMessage,
        reaction: item.reaction,
        isRetry: item.isRetry,
        clearNotificationsIfFromMe: item.clearNotificationsIfFromMe,
        completer: item.completer,
      );
    }
    if (item is OutgoingMultipartMessage) {
      return OutgoingMultipartMessage(
        chat: item.chat,
        message: message,
        isRetry: item.isRetry,
        clearNotificationsIfFromMe: item.clearNotificationsIfFromMe,
        completer: item.completer,
      );
    }
    if (item is OutgoingMessage) {
      return OutgoingMessage(
        chat: item.chat,
        message: message,
        isRetry: item.isRetry,
        clearNotificationsIfFromMe: item.clearNotificationsIfFromMe,
        completer: item.completer,
      );
    }
    if (item is OutgoingAttachment) {
      return OutgoingAttachment(
        chat: item.chat,
        message: message,
        attachment: item.attachment,
        isAudioMessage: item.isAudioMessage,
        isRetry: item.isRetry,
        completer: item.completer,
      );
    }
    throw StateError('Unsupported outgoing item type: ${item.runtimeType}');
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final entry = _queue.removeFirst();
      final item = entry.item;

      try {
        await _handleSend(() => _dispatchItem(item), item.chat).catchError((err) async {
          if (SettingsSvc.settings.cancelQueuedMessages.value) {
            // Cancel all subsequent messages for the same chat.
            final toCancel = _queue.where((e) => e.item.chat.guid == item.chat.guid).map((e) => e.item).toList();
            for (final pending in toCancel) {
              _queue.removeWhere((e) => e.item == pending);
              final m = pending.message;
              final tempGuid = m.guid!;
              m.error = MessageError.BAD_REQUEST.code;
              m.errorMessage = 'Canceled due to previous failure';
              await _finalizeOutgoingFailure(pending.chat, m, tempGuid);
            }
          }
        });
        item.completer?.complete();
      } catch (ex, st) {
        Logger.error('Failed to handle outgoing queue item', error: ex, trace: st, tag: _tag);
        item.completer?.completeError(ex);
      }

      // Recompute the reactive pending set after each item is fully processed.
      pendingChatGuids.assignAll(_queue.map((e) => e.item.chat.guid).toSet());
    }

    _isProcessing = false;
  }

  /// Returns `true` if the message with [tempGuid] is currently waiting in the
  /// queue and has not yet been handed off to the HTTP dispatch layer.
  bool hasPendingMessage(String tempGuid) => _queue.any((e) => e.item.message.guid == tempGuid);

  /// Removes [entries] from the queue, marks each message with
  /// [ClientMessageError.userCanceled], finalizes them via
  /// [_finalizeOutgoingFailure], and recomputes [pendingChatGuids].
  ///
  /// Callers must snapshot the relevant entries *before* passing them in,
  /// since the iterable is evaluated lazily against the live queue.
  Future<void> _cancelEntries(Iterable<_OutgoingEntry> entries) async {
    final toCancel = entries.map((e) => e.item).toList();
    for (final pending in toCancel) {
      _queue.removeWhere((e) => e.item == pending);
      final m = pending.message;
      m.error = ClientMessageError.userCanceled.code;
      m.errorMessage = 'Canceled by user';
      await _finalizeOutgoingFailure(pending.chat, m, m.guid!);
    }
    if (toCancel.isNotEmpty) {
      pendingChatGuids.assignAll(_queue.map((e) => e.item.chat.guid).toSet());
    }
  }

  /// Cancels the single queued message identified by [tempGuid].
  ///
  /// If the message has already been dequeued for dispatch this is a no-op.
  Future<void> cancelMessage(String tempGuid) => _cancelEntries(_queue.where((e) => e.item.message.guid == tempGuid));

  /// Cancels all pending (not-yet-dispatched) outgoing messages for [chatGuid].
  ///
  /// The currently-dispatching item (if any) is left to complete on its own —
  /// only items still waiting in the queue are affected.
  Future<void> cancelPendingForChat(String chatGuid) =>
      _cancelEntries(_queue.where((e) => e.item.chat.guid == chatGuid));

  /// Wraps a send [process] with the send-progress animation:
  ///
  /// * A 5-second timer sets [chat.sendProgress] to 0.9 to signal a long
  ///   send.
  /// * When [process] completes (success or error), the timer is cancelled
  ///   and progress is driven to 1 → 0 (unless an early socket event already
  ///   did so via [completeSendProgressIfExists]).
  Future<T> _handleSend<T>(Future<T> Function() process, Chat chat) {
    final timer = Timer(const Duration(seconds: 5), () {
      chat.sendProgress.value = .9;
    });
    final t = process();
    void _finalize(dynamic _) {
      timer.cancel();
      if (chat.sendProgress.value != 0 && chat.sendProgress.value != 1) {
        chat.sendProgress.value = 1;
        Timer(const Duration(milliseconds: 500), () {
          chat.sendProgress.value = 0;
        });
      }
    }

    t.then(_finalize, onError: _finalize);
    return t;
  }

  /// Fires [httpCall] and races the response against the socket echo for
  /// [tempGuid].  Whichever arrives first unblocks the queue; the HTTP work
  /// (GUID replacement, error marking, etc.) still runs to completion
  /// afterwards in the background.
  ///
  /// [onSuccess] receives the decoded server response body (the full response
  /// map, i.e. `response.data`). Callers extract a [Message] via
  /// `Message.fromMap(data['data'])`.
  /// [onError] receives the original error and stack-trace so the caller can
  /// mark the message as failed and persist the error state.
  /// Both callbacks are wrapped in a try/catch so an internal failure (e.g.,
  /// a transient DB write error) never leaves the queue permanently blocked.
  Future<void> _sendWithRace({
    required String tempGuid,
    required Chat chat,
    required Future<Map<String, dynamic>> Function() httpCall,
    required Future<void> Function(Map<String, dynamic> data) onSuccess,
    required Future<void> Function(Object error, StackTrace stack) onError,
  }) {
    final race = Completer<void>();
    registerSendProgressTracker(tempGuid, chat, race);

    httpCall().then((data) async {
      completeSendProgressIfExists(tempGuid, Origin.outgoingMessageHandler);
      try {
        await onSuccess(data);
      } catch (ex, st) {
        Logger.warn('Send success handler threw for $tempGuid', error: ex, trace: st, tag: _tag);
      }
      if (!race.isCompleted) race.complete();
    }, onError: (Object error, StackTrace stack) async {
      completeSendProgressIfExists(
        tempGuid,
        Origin.outgoingMessageHandler,
        error: error,
        stack: stack,
      );
      try {
        await onError(error, stack);
      } catch (ex, st) {
        Logger.warn('Send error handler threw for $tempGuid', error: ex, trace: st, tag: _tag);
      }
      if (!race.isCompleted) race.completeError(error, stack);
    });

    return race.future;
  }

  Future<void> _dispatchItem(OutgoingQueueItem item) {
    switch (item.type) {
      case QueueType.sendMessage:
        final typed = item as OutgoingMessage;
        return sendMessage(typed.chat, typed.message, null, null);
      case QueueType.sendReaction:
        final typed = item as OutgoingReaction;
        return sendMessage(typed.chat, typed.message, typed.selectedMessage, typed.reaction);
      case QueueType.sendMultipart:
        final typed = item as OutgoingMultipartMessage;
        return sendMultipart(typed.chat, typed.message, null, null);
      case QueueType.sendAttachment:
        final typed = item as OutgoingAttachment;
        return sendAttachment(
          typed.chat,
          typed.message,
          typed.isAudioMessage,
          typed.attachment,
        );
    }
  }

  // ── Preparation ──────────────────────────────────────────────────────────

  /// Determines the [Message] object(s) that a text/multipart/reaction send
  /// resolves to, assigning a temp GUID to any newly-constructed message.
  ///
  /// On macOS < Big Sur, long messages containing a URL are split into two
  /// separate messages to prevent server-side matching glitches — this is the
  /// only case that produces more than one message.
  ///
  /// Pure and synchronous: no DB or file I/O happens here, so it can't itself
  /// throw a transient error that needs retrying. Must be called exactly ONCE
  /// per [queue] invocation, never inside a retry loop — it mutates `m.text`
  /// in place on the split path and hands out a fresh GUID for the secondary
  /// message, so re-running it would desync message identity from whatever a
  /// prior attempt already persisted (see [_persistOutgoingMessages]).
  List<Message> _buildOutgoingMessages(Chat c, Message m, String? r, {required bool isRetry}) {
    // If it's a retry, the message should already be in the correct format
    // and already carries the GUID of the DB row the caller re-persists.
    if (isRetry) return [m];
    if ((m.text?.isEmpty ?? true) && (m.subject?.isEmpty ?? true) && r == null) return [];

    if (!SettingsSvc.serverDetails.isMinBigSur && r == null) {
      // Split URL messages on OS X to prevent message matching glitches.
      String mainText = m.text!;
      String? secondaryText;
      final match = parseLinks(m.text!.replaceAll('\n', ' ')).firstOrNull;
      if (match != null) {
        if (match.start == 0) {
          mainText = m.text!.substring(0, match.end).trimRight();
          secondaryText = m.text!.substring(match.end).trimLeft();
        } else if (match.end == m.text!.length) {
          mainText = m.text!.substring(0, match.start).trimRight();
          secondaryText = m.text!.substring(match.start).trimLeft();
        }
      }

      // m already has a stable GUID, assigned by _ensureTempGuid before prep began.
      final messages = <Message>[m..text = mainText];
      if (!isNullOrEmpty(secondaryText)) {
        final secondary = Message(
          text: secondaryText,
          threadOriginatorGuid: m.threadOriginatorGuid,
          threadOriginatorPart: '${m.threadOriginatorPart ?? 0}:0:0',
          expressiveSendStyleId: m.expressiveSendStyleId,
          dateCreated: DateTime.now(),
          hasAttachments: false,
          isFromMe: true,
          handleId: 0,
        );
        secondary.generateTempGuid();
        messages.add(secondary);
      }
      return messages;
    }

    // m already has a stable GUID, assigned by _ensureTempGuid before prep began.
    return [m];
  }

  /// Persists [messages] (already built by [_buildOutgoingMessages], GUIDs
  /// stable) to the DB and wires them into [MessagesService]/[ChatState].
  ///
  /// Safe to call repeatedly across retry attempts against the same
  /// [messages] list: each message's DB write is skipped if a row with its
  /// GUID already exists (a prior attempt saved it), but the UI-wiring calls
  /// are always (re-)run — they're idempotent (`addNewMessage` no-ops if the
  /// struct already has the GUID; `addAssociatedMessageInternal` updates an
  /// existing entry in place rather than duplicating it).
  Future<List<Message>> _persistOutgoingMessages(
    Chat c,
    List<Message> messages,
    String? r, {
    required bool clearNotificationsIfFromMe,
  }) async {
    final List<Message> saved = [];
    for (final message in messages) {
      final existing = Message.findOne(guid: message.guid);
      final Message hydrated =
          existing ?? (await c.addMessage(message, clearNotificationsIfFromMe: clearNotificationsIfFromMe)).message;
      saved.add(hydrated);

      final msgSvcRegistered = Get.isRegistered<MessagesService>(tag: c.guid);
      if (r != null && message.associatedMessageGuid != null && msgSvcRegistered) {
        // Add temp reaction to UI immediately during prep so it appears without
        // waiting for the serial queue (fixes back-to-back text+reaction send delay).
        final parentState = MessagesSvc(c.guid).getMessageStateIfExists(message.associatedMessageGuid!);
        parentState?.addAssociatedMessageInternal(hydrated);
      } else if (message.associatedMessageGuid == null && msgSvcRegistered) {
        await MessagesSvc(c.guid).addNewMessage(hydrated);
      }
    }
    // Update ChatState immediately so the tile reflects the outgoing message(s)
    // before the queue dispatches the HTTP call.
    if (saved.isNotEmpty) {
      ChatsSvc.updateChatLatestMessage(c.guid, saved.last);
    }
    return saved;
  }

  /// Copies the attachment file to the local storage directory and saves the
  /// message to the DB.
  ///
  /// Attachment metadata carries the original source path so the file can be
  /// copied without loading it into memory (except GIFs, which need
  /// optimisation).
  Future<void> prepAttachment(Chat c, Message m, Attachment? attachment) async {
    if (attachment == null) {
      throw StateError('Missing attachment for sendAttachment prep on message ${m.guid}');
    }

    final progress = AttachmentUploadProgress(attachment.guid!, 0.0.obs);
    attachmentProgress.add(progress);

    if (!kIsWeb) {
      final sourcePath = attachment.metadata?['source_path'] as String?;
      if (sourcePath == null && attachment.bytes == null) {
        throw Exception('Attachment has no source_path in metadata or bytes');
      }

      final destinationPath = attachment.path;
      final destinationFile = await File(destinationPath).create(recursive: true);

      if (sourcePath != null) {
        if (attachment.mimeType == 'image/gif') {
          final bytes = await File(sourcePath).readAsBytes();
          final optimizedBytes = await fixSpeedyGifs(bytes);
          await destinationFile.writeAsBytes(optimizedBytes);
        } else {
          await File(sourcePath).copy(destinationPath);
        }
        // For interactive messages (any balloonBundleId), also stage the media
        // at interactiveMediaPath so EmbeddedMedia can display it on first
        // render without waiting for a server download.
        if (m.balloonBundleId != null) {
          final mediaPath = m.interactiveMediaPath;
          if (mediaPath != null) {
            await File(mediaPath).create(recursive: true);
            await File(destinationPath).copy(mediaPath);
          }
        }
      } else {
        Uint8List bytesToWrite = attachment.bytes!;
        if (attachment.mimeType == 'image/gif') {
          bytesToWrite = await fixSpeedyGifs(bytesToWrite);
        }
        await destinationFile.writeAsBytes(bytesToWrite);

        // For interactive messages (any balloonBundleId), also stage the media
        // at interactiveMediaPath so EmbeddedMedia can display it on first
        // render without waiting for a server download.
        if (m.balloonBundleId != null) {
          final mediaPath = m.interactiveMediaPath;
          if (mediaPath != null) {
            await File(mediaPath).create(recursive: true);
            await File(mediaPath).writeAsBytes(bytesToWrite);
          }
        }

        attachment.bytes = null;
      }

      if (attachment.mimeStart == 'image') {
        try {
          await AttachmentsSvc.loadImageProperties(attachment, actualPath: destinationPath);
        } catch (ex) {
          Logger.warn('Failed to load image properties for outgoing attachment', error: ex, tag: _tag);
        }
      }

      attachment.isDownloaded = true;
    }

    // ChatInterface.addMessageToChat returns a DB-hydrated Message loaded from
    // the main isolate's Store (Database.messages.get(id)) after the
    // GlobalIsolate transaction commits.  This object has its id set and its
    // dbAttachments ToMany linked to the main Store, so _handleNewMessage can
    // reload attachments from DB without racing against cross-isolate write timing.
    final savedMessage = (await c.addMessage(m, attachments: [attachment])).message;

    // The DB write goes through the GlobalIsolate, so the main-isolate OB watch
    // subscription won't fire for it.  Explicitly push the message into the view
    // using the Store-hydrated object so _handleNewMessage can load dbAttachments.
    if (Get.isRegistered<MessagesService>(tag: c.guid)) {
      await MessagesSvc(c.guid).addNewMessage(savedMessage);
      // Register upload-in-progress state.  Must come after addNewMessage so the
      // MessageState already exists.
      MessagesSvc(c.guid).notifyAttachmentUploadStarted(savedMessage, attachment);
    }
    // Update ChatState immediately so the tile reflects the outgoing attachment
    // before the queue dispatches the HTTP call.
    ChatsSvc.updateChatLatestMessage(c.guid, savedMessage);
  }

  // ── Send methods ─────────────────────────────────────────────────────────

  /// Returns `'private-api'` if [m] must be sent via the Private API,
  /// `'apple-script'` otherwise.
  ///
  /// Private API is required when:
  /// - the user has it globally enabled AND the per-type setting is on, OR
  /// - the message uses a feature only pAPI supports (subject, thread
  ///   originator, or expressive effect).
  String _resolveMethod(Message m, {bool forAttachment = false}) {
    final papiEnabled = SettingsSvc.settings.enablePrivateAPI.value;
    final papiSend =
        forAttachment ? SettingsSvc.settings.privateAPIAttachmentSend.value : SettingsSvc.settings.privateAPISend.value;
    if ((papiEnabled && papiSend) ||
        (m.subject?.isNotEmpty ?? false) ||
        m.threadOriginatorGuid != null ||
        m.expressiveSendStyleId != null) {
      return 'private-api';
    }
    return 'apple-script';
  }

  /// Sends a text message (or a reaction/tapback) to [c].
  Future<void> sendMessage(Chat c, Message m, Message? selected, String? r) {
    ChatsSvc.updateChat(c);

    // Only update latest message if the failed message is the current latest message.
    // Prep message should have already updated the latest message.
    if (ChatsSvc.getChatState(c.guid)?.latestMessage.value?.guid == m.guid) {
      ChatsSvc.updateChatLatestMessage(c.guid, m);
    }

    final tempGuid = m.guid!;

    return _sendWithRace(
      tempGuid: tempGuid,
      chat: c,
      httpCall: () => r == null
          ? SendMessageInterface.sendTextMessage(
              chatGuid: c.guid,
              tempGuid: tempGuid,
              message: m.text!,
              method: _resolveMethod(m),
              selectedMessageGuid: m.threadOriginatorGuid,
              effectId: m.expressiveSendStyleId,
              subject: m.subject,
              partIndex: int.tryParse(m.threadOriginatorPart?.split(':').firstOrNull ?? ''),
              ddScan: !SettingsSvc.serverDetails.isMinSonoma && m.text!.hasUrl,
            )
          : SendMessageInterface.sendTapback(
              chatGuid: c.guid,
              selectedMessageText: selected!.text ?? '',
              selectedMessageGuid: selected.guid!,
              reaction: r,
              partIndex: m.associatedMessagePart,
            ),
      onSuccess: (data) => _finalizeOutgoingSuccess(
        c, tempGuid, data,
        // Reactions live in the parent's associatedMessages list, not as
        // top-level MessagesService entries.  Once the GUID is confirmed,
        // explicitly update the parent so the badge reflects the real reaction.
        onExtra: r != null
            ? (confirmed) async {
                if (confirmed.associatedMessageGuid != null) {
                  final parentState =
                      maybeFindMessagesSvc(c.guid)?.getMessageStateIfExists(confirmed.associatedMessageGuid!);
                  if (parentState != null) {
                    parentState.updateAssociatedMessageInternal(confirmed, tempGuid: tempGuid);
                  } else {
                    Logger.warn(
                      'Parent MessageState not found for ${confirmed.associatedMessageGuid} when updating reaction',
                      tag: _tag,
                    );
                  }
                }
              }
            : null,
      ),
      onError: (error, stack) => _finalizeOutgoingFailure(
        c, m, tempGuid,
        logMessage: r == null ? 'Failed to send message' : 'Failed to send reaction',
        error: error,
        stack: stack,
        // Reactions live in the parent's associatedMessages list, not as
        // top-level MessagesService entries, so the standard updateMessage call
        // inside _finalizeOutgoingFailure is a no-op for them.  Explicitly
        // update the parent so the error badge propagates to the UI.
        onExtra: r != null && m.associatedMessageGuid != null
            ? (errorMsg) async {
                maybeFindMessagesSvc(c.guid)
                    ?.getMessageStateIfExists(m.associatedMessageGuid!)
                    ?.updateAssociatedMessageInternal(errorMsg, tempGuid: tempGuid);
              }
            : null,
      ),
    );
  }

  /// Sends a multipart (mention / mixed-content) message.
  Future<void> sendMultipart(Chat c, Message m, Message? selected, String? r) {
    ChatsSvc.updateChat(c);

    // Only update latest message if the failed message is the current latest message.
    // Prep message should have already updated the latest message.
    if (ChatsSvc.getChatState(c.guid)?.latestMessage.value?.guid == m.guid) {
      ChatsSvc.updateChatLatestMessage(c.guid, m);
    }

    final tempGuid = m.guid!;
    final parts = m.attributedBody.first.runs
        .map((e) => {
              'text': m.attributedBody.first.string.substring(e.range.first, e.range.first + e.range.last),
              'mention': e.attributes!.mention,
              'partIndex': e.attributes!.messagePart,
            })
        .toList();

    return _sendWithRace(
      tempGuid: tempGuid,
      chat: c,
      httpCall: () => SendMessageInterface.sendMultipartMessage(
        chatGuid: c.guid,
        tempGuid: tempGuid,
        parts: parts,
        subject: m.subject,
        selectedMessageGuid: m.threadOriginatorGuid,
        effectId: m.expressiveSendStyleId,
        partIndex: int.tryParse(m.threadOriginatorPart?.split(':').firstOrNull ?? ''),
        ddScan: !SettingsSvc.serverDetails.isMinSonoma && parts.any((e) => e['text'].toString().hasUrl),
      ),
      onSuccess: (data) => _finalizeOutgoingSuccess(c, tempGuid, data),
      onError: (error, stack) => _finalizeOutgoingFailure(
        c,
        m,
        tempGuid,
        logMessage: 'Failed to send multipart message',
        error: error,
        stack: stack,
      ),
    );
  }

  /// Sends an attachment message.
  Future<void> sendAttachment(Chat c, Message m, bool isAudioMessage, Attachment? attachment) async {
    if (attachment == null) {
      throw StateError('Missing attachment for sendAttachment on message ${m.guid}');
    }

    // Save both GUIDs before any mutation — attachment.guid == m.guid by design
    // (set in send_animation.dart: attachment.guid = message.guid).
    final tempGuid = m.guid!;
    // The temp message was already saved to DB in prepAttachment; update ChatState
    // subtitle immediately so the tile reflects the outgoing attachment.

    // Only update latest message if the attachment message is the current latest message.
    // Prep attachment should have already updated the latest message.
    if (ChatsSvc.getChatState(c.guid)?.latestMessage.value?.guid == m.guid) {
      ChatsSvc.updateChatLatestMessage(c.guid, m);
    }

    // On web the isolate path is not supported (web is deprecated).
    if (kIsWeb) return;

    // Fail fast if the file was not staged correctly during prepAttachment.
    if (!File(attachment.path).existsSync()) {
      Logger.error('Attachment file not found at ${attachment.path}', tag: _tag);
      return;
    }

    return _sendWithRace(
      tempGuid: tempGuid,
      chat: c,
      httpCall: () => SendMessageInterface.sendAttachmentMessage(
        chatGuid: c.guid,
        tempGuid: attachment.guid!,
        filePath: attachment.path,
        fileName: attachment.transferName!,
        fileSize: attachment.totalBytes ?? 0,
        method: _resolveMethod(m, forAttachment: true),
        selectedMessageGuid: m.threadOriginatorGuid,
        effectId: m.expressiveSendStyleId,
        partIndex: int.tryParse(m.threadOriginatorPart?.split(':').firstOrNull ?? ''),
        isAudioMessage: isAudioMessage,
      ),
      onSuccess: (Map<String, dynamic> data) async {
        final newMessage = Message.fromMap(data['data']);
        final responseAttachments = ((data['data']?['attachments'] as List?) ?? <dynamic>[])
            .whereType<Map>()
            .map((e) => Attachment.fromMap(e.cast<String, Object>()))
            .toList();
        // Swap attachment GUIDs first, then swap the message GUID.
        for (final a in responseAttachments) {
          try {
            await _matchAttachmentWithExisting(c, tempGuid, a);
            // Complete the attachment state.  We pass both the temp and real
            // message GUIDs because the socket event may have already moved
            // the MessageState to the real key before the HTTP response arrived.
            // The state key is intentionally left at the temp attachment GUID
            // so the Obx can still find it; _syncAttachmentStates promotes it
            // to the real key when updateMessage delivers the updated struct.
            if (Get.isRegistered<MessagesService>(tag: c.guid)) {
              MessagesSvc(c.guid).notifyAttachmentSendComplete(tempGuid, newMessage.guid!, tempGuid, a);
              MessagesSvc(c.guid).updateMessage(newMessage);
            }
          } catch (e, st) {
            Logger.warn('Failed to replace attachment ${a.guid}', error: e, trace: st, tag: _tag);
          }
        }
        await _matchMessageWithExisting(c, tempGuid, newMessage);
        attachmentProgress.removeWhere((e) => e.guid == tempGuid);
      },
      onError: (error, stack) => _finalizeOutgoingFailure(
        c,
        m,
        tempGuid,
        logMessage: 'Failed to send attachment',
        error: error,
        stack: stack,
        onExtra: (errorMsg) async {
          // updateMessage (inside _finalizeOutgoingFailure) has already
          // re-keyed MessageState to errorMsg.guid, so notifyAttachmentTransferError
          // can use that key directly.
          if (Get.isRegistered<MessagesService>(tag: c.guid)) {
            MessagesSvc(c.guid).notifyAttachmentTransferError(errorMsg.guid!, attachment.guid!);
          }
          attachmentProgress.removeWhere((e) => e.guid == tempGuid);
        },
      ),
    );
  }

  // ── Finalization helpers ─────────────────────────────────────────────────

  /// Centralises the post-success steps shared by text and multipart send paths:
  ///
  /// 1. Parses the server-confirmed [Message] from [data].
  /// 2. Calls [_matchMessageWithExisting] to swap the temp DB record and update
  ///    [ChatState] with the confirmed message.
  /// 3. Calls [onExtra] with the confirmed message for type-specific
  ///    side-effects (e.g. updating a reaction parent's UI state).
  ///
  /// Note: [sendAttachment] success is intentionally handled inline because
  /// attachment GUID swaps must complete *before* the message GUID swap — an
  /// ordering constraint that doesn't fit the [onExtra] model.
  Future<void> _finalizeOutgoingSuccess(
    Chat c,
    String tempGuid,
    Map<String, dynamic> data, {
    Future<void> Function(Message confirmed)? onExtra,
  }) async {
    final serverMessage = Message.fromMap(data['data']);
    await _matchMessageWithExisting(c, tempGuid, serverMessage);
    await onExtra?.call(serverMessage);
  }

  /// Centralises the post-failure steps shared by every outgoing send path:
  ///
  /// 1. Logs at error level when [logMessage] is non-null.
  /// 2. When [error] is non-null: classifies it via [handleSendError] and
  ///    posts a "failed to send" notification if the UI is no longer alive.
  /// 3. Replaces the temp DB record with the error-state message.
  /// 4. Propagates the update to [MessagesService] and [ChatState].
  /// 5. Calls [onExtra] for type-specific side-effects (e.g. attachment
  ///    progress cleanup, reaction parent update).
  ///
  /// Returns the DB-hydrated error [Message] for callers that need it.
  Future<Message> _finalizeOutgoingFailure(
    Chat c,
    Message m,
    String tempGuid, {
    String? logMessage,
    Object? error,
    StackTrace? stack,
    Future<void> Function(Message errorMsg)? onExtra,
  }) async {
    if (logMessage != null) {
      Logger.error(logMessage, error: error, trace: stack, tag: _tag);
    }
    if (error != null) {
      m = handleSendError(error, m);
      if (!LifecycleSvc.isAlive || !(ChatsSvc.getChatController(c.guid)?.isAlive.value ?? false)) {
        await NotificationsSvc.createFailedToSend(c);
      }
    }

    try {
      // Replace may fail, meaning it's already been replaced (likely by a socket event)
      final errorMsg = await Message.replaceMessage(tempGuid, m);
      if (Get.isRegistered<MessagesService>(tag: c.guid)) {
        MessagesSvc(c.guid).updateMessage(errorMsg, oldGuid: tempGuid);
      }

      // Only update latest message if the failed message is the current latest message.
      if (ChatsSvc.getChatState(c.guid)?.latestMessage.value?.guid == tempGuid) {
        ChatsSvc.updateChatLatestMessage(c.guid, errorMsg);
      }

      await onExtra?.call(errorMsg);
      return errorMsg;
    } catch (ex, st) {
      Logger.warn(ex.toString(), error: ex, trace: st, tag: _tag);
      return m;
    }
  }

  // ── DB helpers ──────────────────────────────────────────────────────────

  /// Replaces the temp message record ([existingGuid]) with [replacement] in
  /// the DB and notifies [MessagesService] so the UI bubble transitions.
  ///
  /// Handles the parallel-delivery race where [IncomingMessageHandler] may
  /// have already processed the socket echo:
  ///
  /// * If [replacement.guid] is already in the DB (socket beat HTTP): update
  ///   the existing record if [replacement] is newer, clean up the stale temp,
  ///   and update the controller.
  /// * Otherwise: call [Message.replaceMessage] to rename the temp record to
  ///   the real GUID.
  Future<void> _matchMessageWithExisting(
    Chat chat,
    String existingGuid,
    Message replacement,
  ) async {
    final alreadyPresent = Message.findOne(guid: replacement.guid);

    // Track the DB-hydrated confirmed message so we can update ChatState after the swap.
    late Message _confirmedMessage;

    if (alreadyPresent != null) {
      // Socket event won the race — real GUID is already in the DB.
      final isNewer = replacement.isNewerThan(alreadyPresent);
      if (isNewer) {
        try {
          await Message.replaceMessage(replacement.guid, replacement);
        } catch (ex, st) {
          Logger.warn(
              'Unable to replace message with GUID, "${replacement.guid}". The socket likely confirmed the message first.',
              error: ex,
              trace: st,
              tag: _tag);
        }
      }
      // alreadyPresent was fetched from the DB and has a valid id.
      _confirmedMessage = alreadyPresent;

      // Clean up the stale temp record if it's distinct from the real one.
      if (existingGuid != replacement.guid) {
        final stale = Message.findOne(guid: existingGuid);
        if (stale != null) {
          Message.delete(stale.guid!);
          if (Get.isRegistered<MessagesService>(tag: chat.guid)) {
            MessagesSvc(chat.guid).updateMessage(replacement, oldGuid: existingGuid);
          }
        }
      } else {}
    } else {
      // Normal path: rename the temp record to the real GUID.
      try {
        // Capture the return value — it is fetched from the DB and has a valid id.
        final saved = await Message.replaceMessage(existingGuid, replacement);
        _confirmedMessage = saved;
        if (Get.isRegistered<MessagesService>(tag: chat.guid)) {
          MessagesSvc(chat.guid).updateMessage(saved, oldGuid: existingGuid);
        }
      } catch (ex, st) {
        // If the temp message isn't found in the isolate store, it was never saved.
        // This can happen if prepMessage failed silently. Fall back to just saving
        // the replacement message and updating the UI.
        Logger.warn(
          'Unable to replace message with GUID "$existingGuid". Socket likely confirmed the message first.',
          error: ex,
          trace: st,
          tag: _tag,
        );

        // Instead of trying to replace, just save the replacement and update the UI to use it.
        // This handles the case where the temp message was never saved to the main thread's store.
        replacement.save(); // sets replacement.id via Database.messages.put()
        _confirmedMessage = replacement;
        if (Get.isRegistered<MessagesService>(tag: chat.guid)) {
          // Update the UI, treating this as transitioning from temp to real GUID
          MessagesSvc(chat.guid).updateMessage(replacement, oldGuid: existingGuid);
        }
      }
    }

    // Only update latest message if the failed message is the current latest message.
    if (ChatsSvc.getChatState(chat.guid)?.latestMessage.value?.guid == existingGuid) {
      ChatsSvc.updateChatLatestMessage(chat.guid, _confirmedMessage);
    }

    // Move the interactive media directory (for handwriten / digital-touch
    // messages) from the temp-GUID path to the real-GUID path so that
    // EmbeddedMedia.getContent finds the pre-staged local file immediately
    // instead of falling back to a server download.
    if (!kIsWeb && existingGuid != replacement.guid && existingGuid.startsWith('temp')) {
      try {
        final oldMessageDir = Directory(join(FilesystemSvc.messagesPath, existingGuid));
        final newMessageDir = Directory(join(FilesystemSvc.messagesPath, replacement.guid!));
        if (oldMessageDir.existsSync() && !newMessageDir.existsSync()) {
          oldMessageDir.renameSync(newMessageDir.path);
        }
      } catch (ex) {
        Logger.warn(
          '[_matchMessageWithExisting] failed to move message media dir $existingGuid → ${replacement.guid}',
          error: ex,
          tag: _tag,
        );
      }
    }
  }

  /// Swaps a temp attachment GUID for the real one after the server confirms
  /// the upload.
  Future<void> _matchAttachmentWithExisting(
    Chat chat,
    String existingGuid,
    Attachment replacement,
  ) async {
    final alreadyPresent = await Attachment.findOneAsync(replacement.guid!);
    if (alreadyPresent != null) {
      await Attachment.replaceAttachmentAsync(replacement.guid, replacement);
      if (existingGuid != replacement.guid) {
        final stale = await Attachment.findOneAsync(existingGuid);
        if (stale != null) {
          await Attachment.deleteAsync(stale.guid!);
        }
      } else {}
    } else {
      try {
        await Attachment.replaceAttachmentAsync(existingGuid, replacement);
      } catch (ex) {
        Logger.warn(
          '[_matchAttachmentWithExisting] FAILED: Unable to find & replace attachment with GUID $existingGuid',
          error: ex,
          tag: _tag,
        );
      }
    }

    // Move the file directory from the temp-GUID path to the real-GUID path so that
    // getContent finds the local file immediately without triggering a server download.
    if (!kIsWeb && existingGuid != replacement.guid && existingGuid.startsWith('temp')) {
      try {
        final oldDir = Directory('${Attachment.baseDirectory}/$existingGuid');
        final newDir = Directory(replacement.directory);
        if (oldDir.existsSync() && !newDir.existsSync()) {
          oldDir.renameSync(newDir.path);
        }
      } catch (ex) {
        Logger.warn(
          '[_matchAttachmentWithExisting] failed to move attachment dir $existingGuid → ${replacement.guid}',
          error: ex,
          tag: _tag,
        );
      }
    }
  }

  // ── Service lifecycle ────────────────────────────────────────────────────

  /// Cancels pending progress timers and fails any queued items.
  ///
  /// Called by GetIt when the singleton is unregistered.
  void dispose() {
    if (GetIt.I.isRegistered<GlobalIsolate>()) {
      GetIt.I<GlobalIsolate>()
          .removeEventListener(IsolateEvent.attachmentUploadProgress, _handleAttachmentUploadProgressEvent);
    }

    latestCancelToken?.cancel('OutgoingMessageHandler disposed');
    latestCancelToken = null;
    _sendProgressTrackers.clear();

    while (_queue.isNotEmpty) {
      final entry = _queue.removeFirst();
      entry.item.completer?.completeError(
        StateError('OutgoingMessageHandler disposed before item was processed'),
      );
    }

    _isProcessing = false;
  }
}
