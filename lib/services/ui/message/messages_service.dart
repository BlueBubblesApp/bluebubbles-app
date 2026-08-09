import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/app/state/attachment_state.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/helpers/types/extensions/extensions.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/backend/interfaces/sync_interface.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:bluebubbles/models/models.dart' show AttachmentUploadProgress, MessageReceiptInfo;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

MessagesService? maybeFindMessagesSvc(String chatGuid) =>
    Get.isRegistered<MessagesService>(tag: chatGuid) ? Get.find<MessagesService>(tag: chatGuid) : null;

MessagesService ensureMessagesSvc(String chatGuid) =>
    maybeFindMessagesSvc(chatGuid) ??
    Get.put(
      MessagesService(chatGuid),
      tag: chatGuid,
      permanent: true,
    );

MessagesService registerMessagesSvc(MessagesService service) =>
    maybeFindMessagesSvc(service.tag) ??
    Get.put(
      service,
      tag: service.tag,
      permanent: true,
    );

// ignore: non_constant_identifier_names
MessagesService MessagesSvc(String chatGuid) {
  final service = maybeFindMessagesSvc(chatGuid);
  if (service == null) {
    throw StateError(
      'MessagesService for chat $chatGuid is not registered. Only UI owner code should create it.',
    );
  }
  return service;
}

String? lastReloadedChat() =>
    Get.isRegistered<String>(tag: 'lastReloadedChat') ? Get.find<String>(tag: 'lastReloadedChat') : null;

class MessagesService extends GetxController {
  static final Map<String, Size> cachedBubbleSizes = {};
  late Chat chat;
  StreamSubscription? _webMessageSub;
  final ChatMessages struct = ChatMessages();
  late Function(Message) newFunc;
  late Function(Message, {String? oldGuid}) updateFunc;
  late Function(Message) removeFunc;
  late Function(String) jumpToMessage;
  late List<Message> messagesRef;

  final String tag;
  MessagesService(this.tag);

  bool _init = false;
  bool messagesLoaded = false;
  String? method;

  /// The view (State) currently driving this service. When a second
  /// ConversationView for the same chat is pushed (e.g. from a notification tap),
  /// both routes share this tagged instance — the superseded view's dispose must
  /// not delete it out from under its successor. See MessagesServiceMixin.
  Object? owner;

  /// Map of message states for granular reactivity
  /// Key is message GUID, value is MessageState
  /// Provides O(1) lookups and granular observable fields
  final Map<String, MessageState> messageStates = {};

  /// Listeners for redacted mode settings to update all MessageStates
  StreamSubscription? _redactedModeListener;
  StreamSubscription? _hideMessageContentListener;
  StreamSubscription? _hideAttachmentsListener;

  /// Granular reactivity map to track individual message updates
  /// Key: message guid, Value: timestamp of last update
  final RxMap<String, int> messageUpdateTrigger = <String, int>{}.obs;

  // ========== Delivered Indicator Tracking ==========
  // Plain (non-reactive) fields — DeliveredIndicator widgets observe the three
  // RxBool flags on each MessageState, not these tracking objects.

  /// Tracks the outgoing message that currently owns the "Read" indicator tier.
  MessageReceiptInfo? _lastReadInfo;

  /// Tracks the outgoing message that currently owns the "Delivered" indicator tier.
  MessageReceiptInfo? _lastDeliveredInfo;

  // ========== End Delivered Indicator Tracking ==========

  Message? get mostRecentSent => (struct.messages.where((e) => e.isFromMe!).toList()..sort(Message.sort)).firstOrNull;

  Message? get mostRecent => (struct.messages.toList()..sort(Message.sort)).firstOrNull;

  Message? get mostRecentReceived =>
      (struct.messages.where((e) => !e.isFromMe!).toList()..sort(Message.sort)).firstOrNull;

  // ========== MessageState Management ==========

  /// Get or create a MessageState for a specific message GUID
  /// Creates the state if it doesn't exist
  /// Throws if message doesn't exist in struct
  MessageState getOrCreateMessageState(String guid) {
    if (!messageStates.containsKey(guid)) {
      final message = struct.getMessage(guid);
      if (message == null) {
        throw Exception('Cannot create MessageState: Message $guid not found in struct');
      }
      final state = MessageState(message);
      state.onInit();
      messageStates[guid] = state;
      Logger.debug("Created MessageState for message $guid", tag: "MessageState");
    }
    return messageStates[guid]!;
  }

  /// Get or create a [MessageState] for [message], initialising it if new.
  /// This is the widget-facing entry point (replaces getOrCreateController).
  MessageState getOrCreateState(Message message) {
    final guid = message.guid!;
    if (!messageStates.containsKey(guid)) {
      final state = MessageState(message);
      state.onInit();
      messageStates[guid] = state;
      Logger.debug("Created MessageState for message $guid", tag: "MessageState");
    }
    return messageStates[guid]!;
  }

  /// Get MessageState if it exists, null otherwise
  /// Use this when you're not sure if the message exists
  MessageState? getMessageStateIfExists(String guid) {
    return messageStates[guid];
  }

  /// Sync a MessageState from the database
  /// Call this after any external DB update that doesn't go through MessagesService
  /// This ensures MessageState stays in sync with DB changes
  void syncMessageStateFromDB(String guid) {
    final message = Message.findOne(guid: guid);
    if (message != null) {
      final state = messageStates[guid];
      if (state != null) {
        state.updateFromMessage(message);
        Logger.debug("Synced MessageState from DB for message $guid", tag: "MessageState");
      } else {
        // State doesn't exist, create it
        messageStates[guid] = MessageState(message);
        Logger.debug("Created MessageState from DB sync for message $guid", tag: "MessageState");
      }
    }
  }

  /// Ensure MessageStates exist for a list of messages
  /// Creates states for messages that don't have them yet
  void _ensureMessageStates(List<Message> messages) {
    for (final message in messages) {
      if (message.guid != null && !messageStates.containsKey(message.guid)) {
        final state = MessageState(message);
        state.onInit();
        messageStates[message.guid!] = state;
      }
      // Re-apply uploading state for any attachment that is still actively
      // being sent.  When MessagesService is torn down (user navigates away)
      // and then re-created (user re-enters), AttachmentState is constructed
      // fresh from the persisted data.  Because prepAttachment sets
      // isDownloaded=true before the upload completes, the constructor
      // defaults those attachments to transferState=complete/isSending=false,
      // hiding the in-progress send overlay.  This call corrects that.
      _restoreInFlightAttachmentStates(message);
    }
  }

  /// For each temp-GUID attachment on [message] that is actively tracked in
  /// [OutgoingMsgHandler.attachmentProgress], transitions the [AttachmentState]
  /// to [AttachmentTransferState.uploading] and populates
  /// [AttachmentState.uploadPreviewFile] from the local file — so re-entering
  /// a chat mid-upload immediately shows the correct progress UI instead of
  /// a brief [NotLoadedContent] flash.
  ///
  /// Only called for messages whose GUID starts with `temp`; non-temp messages
  /// and stale orphaned temp records (upload progress not in tracker) are
  /// left unchanged so existing behaviour is undisturbed.
  void _restoreInFlightAttachmentStates(Message message) {
    if (kIsWeb) return;
    final msgGuid = message.guid;
    if (msgGuid == null) return;

    for (final attachment in message.dbAttachments) {
      if (attachment.guid == null || !(attachment.guid!.startsWith('temp'))) continue;
      // Only restore if the upload is actively tracked in the singleton handler.
      // This intentionally skips stale temp records from crashed/killed sessions.
      final inFlight = OutgoingMsgHandler.attachmentProgress.firstWhereOrNull((e) => e.guid == attachment.guid);
      if (inFlight == null) continue;

      final msgState = messageStates[msgGuid];
      if (msgState == null) continue;

      final attState = msgState.getOrCreateAttachmentState(attachment.guid!, attachment: attachment);
      if (attState.transferState.value != AttachmentTransferState.uploading) {
        attState.updateTransferStateInternal(AttachmentTransferState.uploading, progress: inFlight.progress.value);
      } else {
        // Already uploading (same service instance, mid-upload refresh).
        // Sync the current progress value without a full state transition.
        attState.updateUploadProgressInternal(inFlight.progress.value);
      }

      // Populate the preview file so UploadProgressContent can render the
      // image behind the progress overlay immediately on re-entry.
      if (attState.uploadPreviewFile.value == null && attachment.transferName != null) {
        final pathName = attachment.path;
        if (File(pathName).existsSync()) {
          attState.updateUploadPreviewFileInternal(PlatformFile(
            name: attachment.transferName!,
            path: pathName,
            size: attachment.totalBytes ?? 0,
          ));
        }
      }

      Logger.debug(
        'Restored in-flight upload state for attachment ${attachment.guid} (msg $msgGuid)',
        tag: 'AttachmentState',
      );
    }
  }

  // ========== End MessageState Management ==========

  // ========== AttachmentState Management ==========

  /// Returns the [AttachmentState] for [attachmentGuid] within the message
  /// identified by [messageGuid], or `null` if either state does not exist.
  AttachmentState? getAttachmentState(String messageGuid, String attachmentGuid) {
    return messageStates[messageGuid]?.getAttachmentState(attachmentGuid);
  }

  /// Notifies that an attachment upload is starting (called from
  /// [OutgoingMessageHandler.prepAttachment] before the HTTP call is made).
  ///
  /// Ensures the message and attachment are registered in the state maps and
  /// transitions the attachment to [AttachmentTransferState.uploading].
  void notifyAttachmentUploadStarted(Message message, Attachment attachment) {
    if (message.guid == null || attachment.guid == null) return;

    // Ensure the message is in the struct (the ObjectBox watch debounce may
    // not have fired yet at this point).
    if (struct.getMessage(message.guid!) == null) {
      struct.addMessages([message]);
    }

    // Create MessageState if it doesn't exist yet.
    if (!messageStates.containsKey(message.guid!)) {
      final state = MessageState(message);
      state.onInit();
      messageStates[message.guid!] = state;
      Logger.debug("Created MessageState for outgoing message ${message.guid}", tag: "AttachmentState");
    }

    final messageState = messageStates[message.guid!]!;
    final attachmentState = messageState.getOrCreateAttachmentState(attachment.guid!, attachment: attachment);
    attachmentState.updateTransferStateInternal(AttachmentTransferState.uploading);

    // Populate uploadPreviewFile so the UI can show the image behind the
    // progress overlay while the upload is in flight.  The file was already
    // copied to attachment.path by prepAttachment.
    if (!kIsWeb && attachment.transferName != null) {
      final path = attachment.path;
      if (path.isNotEmpty && File(path).existsSync()) {
        attachmentState.updateUploadPreviewFileInternal(PlatformFile(
          name: attachment.transferName!,
          path: path,
          size: attachment.totalBytes ?? 0,
        ));
      }
    }

    Logger.debug(
      "AttachmentState[${attachment.guid}] → uploading (msg ${message.guid})",
      tag: "AttachmentState",
    );
  }

  /// Updates the upload progress for an attachment in flight.
  /// [progress] is a value in [0.0, 1.0].
  void notifyAttachmentUploadProgress(String messageGuid, String attachmentGuid, double progress) {
    messageStates[messageGuid]?.getAttachmentState(attachmentGuid)?.updateUploadProgressInternal(progress);
  }

  /// Notifies that an attachment download has started.
  ///
  /// Transitions the attachment state to [AttachmentTransferState.downloading]
  /// and wires [ctrl.progress] into [AttachmentState.downloadProgress] so the
  /// UI receives live progress updates reactively.
  void notifyAttachmentDownloadStarted(String messageGuid, String attachmentGuid, AttachmentDownloadController ctrl) {
    final messageState = messageStates[messageGuid];
    if (messageState == null) return;

    AttachmentState attachmentState;
    try {
      attachmentState = messageState.getOrCreateAttachmentState(
        attachmentGuid,
        attachment: ctrl.attachment,
      );
    } catch (_) {
      // Message may not have the attachment object yet; create a bare state.
      attachmentState = AttachmentState(ctrl.attachment);
      messageState.attachmentStates[attachmentGuid] = attachmentState;
    }

    attachmentState.updateTransferStateInternal(AttachmentTransferState.downloading);
    attachmentState.updateActiveDownloadInternal(ctrl);
    attachmentState.syncDownloadInternal(ctrl, (PlatformFile file) {
      _onAttachmentDownloadComplete(messageGuid, attachmentGuid, file);
    });

    Logger.debug(
      "AttachmentState[$attachmentGuid] → downloading (msg $messageGuid)",
      tag: "AttachmentState",
    );
  }

  /// Marks an attachment as fully downloaded and transitions its state to
  /// [AttachmentTransferState.complete].
  void notifyAttachmentDownloadComplete(String messageGuid, String attachmentGuid) {
    final state = messageStates[messageGuid]?.getAttachmentState(attachmentGuid);
    if (state == null) return;

    state.updateIsDownloadedInternal(true);
    state.updateActiveDownloadInternal(null);
    state.updateTransferStateInternal(AttachmentTransferState.complete);

    Logger.debug(
      "AttachmentState[$attachmentGuid] → complete (msg $messageGuid)",
      tag: "AttachmentState",
    );
  }

  /// Transitions an attachment to [AttachmentTransferState.error].
  void notifyAttachmentTransferError(String messageGuid, String attachmentGuid) {
    messageStates[messageGuid]
        ?.getAttachmentState(attachmentGuid)
        ?.updateTransferStateInternal(AttachmentTransferState.error);

    Logger.debug(
      "AttachmentState[$attachmentGuid] → error (msg $messageGuid)",
      tag: "AttachmentState",
    );
  }

  /// Re-keys an [AttachmentState] from [oldAttachmentGuid] to
  /// [newAttachmentGuid] within the message identified by [messageGuid].
  ///
  /// Called after an attachment GUID swap (temp → real) so that the state
  /// object survives the transition.  The [AttachmentState.guid] observable is
  /// also updated so reactive listeners receive the new value.
  void renameAttachmentState(String messageGuid, String oldAttachmentGuid, String newAttachmentGuid) {
    if (oldAttachmentGuid == newAttachmentGuid) return;

    final messageState = messageStates[messageGuid];
    if (messageState == null) return;

    final oldState = messageState.attachmentStates.remove(oldAttachmentGuid);
    if (oldState != null) {
      oldState.updateGuidInternal(newAttachmentGuid);
      messageState.attachmentStates[newAttachmentGuid] = oldState;
      Logger.debug(
        "Renamed AttachmentState $oldAttachmentGuid → $newAttachmentGuid (msg $messageGuid)",
        tag: "AttachmentState",
      );
    }
  }

  // ========== End AttachmentState Management ==========

  // ========== Attachment Send Completion ==========

  /// Called after the server confirms an outgoing attachment upload, or when
  /// the incoming handler replaces a temp attachment with the real one.
  ///
  /// Finds the attachment state at [tempAttachmentGuid] — the ORIGINAL key
  /// the state was stored under — and updates it in-place WITHOUT renaming
  /// the map key.  This is intentional: the widget's [_attachmentState] getter
  /// looks up by [part.attachments.first.guid] (always the temp GUID) so it
  /// must be able to find the state even after the Obx re-runs.  The deferred
  /// key rename from temp → real happens lazily in [_syncAttachmentStates]
  /// once [updateMessage] delivers the updated message struct.
  ///
  /// [tempMessageGuid] and [realMessageGuid] are used to locate the
  /// [MessageState]: the temp GUID is tried first (HTTP beats socket); the
  /// real GUID is the fallback for when the socket arrived first and the
  /// MessageState was already moved.
  void notifyAttachmentSendComplete(
    String tempMessageGuid,
    String realMessageGuid,
    String tempAttachmentGuid,
    Attachment resolvedAttachment,
  ) {
    final realAttGuid = resolvedAttachment.guid!;

    // Locate the MessageState — try temp key first, fall back to real.
    MessageState? messageState = messageStates[tempMessageGuid];
    if (messageState == null && realMessageGuid != tempMessageGuid) {
      messageState = messageStates[realMessageGuid];
    }
    if (messageState == null) {
      Logger.warn(
        'notifyAttachmentSendComplete: no MessageState for tempMsg=$tempMessageGuid / realMsg=$realMessageGuid',
        tag: 'AttachmentState',
      );
      return;
    }

    // Register the temp→real mapping so _syncAttachmentStates can promote the
    // correct state key deterministically (critical for multi-attachment messages).
    if (tempAttachmentGuid != realAttGuid) {
      messageState.registerGuidPromotion(tempAttachmentGuid, realAttGuid);
    }

    // Look up state by temp GUID.  If it was already promoted (rare race),
    // fall back to the real key.
    AttachmentState? state = messageState.attachmentStates[tempAttachmentGuid];
    if (state == null && tempAttachmentGuid != realAttGuid) {
      state = messageState.attachmentStates[realAttGuid];
    }
    if (state == null) {
      state = AttachmentState(resolvedAttachment);
      messageState.attachmentStates[tempAttachmentGuid] = state;
    }

    // Sync all metadata (guid, transferName, dimensions, …) so that
    // state.attachment.path uses the real transferName and guid.
    state.updateFromAttachment(resolvedAttachment);

    // Populate resolvedFile if we don't have it yet.
    if (!kIsWeb && state.resolvedFile.value == null && resolvedAttachment.transferName != null) {
      final filePath = resolvedAttachment.path;
      if (File(filePath).existsSync()) {
        state.updateResolvedFileInternal(PlatformFile(
          name: resolvedAttachment.transferName!,
          path: filePath,
          size: resolvedAttachment.totalBytes ?? 0,
        ));
      } else {
        Logger.warn(
          'notifyAttachmentSendComplete: file not found at $filePath '
          'dirContents=${_listDir(resolvedAttachment.directory)}',
          tag: 'AttachmentState',
        );
      }
    }

    // Force-complete the state.  updateFromAttachment's isDownloaded guard
    // may skip the transition when isDownloaded was already true (set in
    // prepAttachment), so we do it explicitly here.
    state.updateIsDownloadedInternal(true);
    state.updateActiveDownloadInternal(null);
    if (state.transferState.value != AttachmentTransferState.complete) {
      state.updateTransferStateInternal(AttachmentTransferState.complete);
    }

    Logger.debug(
      'AttachmentState[$tempAttachmentGuid] → complete '
      '(will promote to $realAttGuid on next _syncAttachmentStates)',
      tag: 'AttachmentState',
    );
  }

  /// Helper: safely lists file names in [dirPath] for debug logging.
  static String _listDir(String dirPath) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return '<dir missing>';
      final names = dir.listSync().map((e) => e.path.split('/').last).join(', ');
      return names.isEmpty ? '<empty dir>' : names;
    } catch (_) {
      return '<error listing dir>';
    }
  }

  // ========== End Attachment Send Completion ==========

  /// Called by [MessagesService] when a download controller confirms the file.
  /// Updates [AttachmentState.resolvedFile] and clears [activeDownload] before
  /// delegating to [notifyAttachmentDownloadComplete].
  void _onAttachmentDownloadComplete(String messageGuid, String attachmentGuid, PlatformFile file) {
    final attState = messageStates[messageGuid]?.getAttachmentState(attachmentGuid);
    if (attState == null) return;
    attState.updateResolvedFileInternal(file);
    attState.updateActiveDownloadInternal(null);
    notifyAttachmentDownloadComplete(messageGuid, attachmentGuid);
  }

  /// Loads the renderable content for [attachment] and updates its
  /// [AttachmentState] accordingly.  Replaces the per-widget `updateContent`
  /// logic so all download orchestration lives in the service layer.
  ///
  /// Safe to call on every widget build — early-returns when the content is
  /// already resolved or a transfer is already in progress.
  Future<void> loadAttachmentContent(String messageGuid, Attachment attachment) async {
    if (attachment.guid == null) return;

    final msgState = messageStates[messageGuid];
    if (msgState == null) return;

    final attState = msgState.getOrCreateAttachmentState(attachment.guid!, attachment: attachment);

    // Don't interfere with active or already-resolved transfers.
    final ts = attState.transferState.value;
    if (ts == AttachmentTransferState.uploading) return;
    if (ts == AttachmentTransferState.downloading || ts == AttachmentTransferState.queued) return;
    if (ts == AttachmentTransferState.complete &&
        attState.resolvedFile.value != null &&
        attState.guid.value == attachment.guid) {
      return;
    }

    final content = AttachmentsSvc.getContent(attachment, onComplete: (PlatformFile file) {
      _onAttachmentDownloadComplete(messageGuid, attachment.guid!, file);
    });

    if (content is PlatformFile) {
      attState.updateResolvedFileInternal(content);
      attState.updateIsDownloadedInternal(true);
      if (attState.transferState.value != AttachmentTransferState.complete) {
        attState.updateTransferStateInternal(AttachmentTransferState.complete);
      }
      return;
    }

    if (content is AttachmentDownloadController) {
      attState.updateActiveDownloadInternal(content);
      notifyAttachmentDownloadStarted(messageGuid, attachment.guid!, content);
      return;
    }

    if (content is AttachmentWithProgress) {
      attState.updateUploadPreviewFileInternal(content.file);
      if (attState.transferState.value != AttachmentTransferState.uploading) {
        attState.updateTransferStateInternal(AttachmentTransferState.uploading);
      }
      return;
    }

    if (content is AttachmentUploadProgress) {
      // Upload in progress without an accessible preview file.
      if (attState.transferState.value != AttachmentTransferState.uploading) {
        attState.updateTransferStateInternal(AttachmentTransferState.uploading);
      }
      return;
    }

    if (content is Attachment) {
      if (attachment.guid?.startsWith('temp') ?? false) return;
      final messageError = struct.getMessage(messageGuid)?.error ?? 0;
      if (messageError != 0) return;

      if (await AttachmentsSvc.canAutoDownload()) {
        _startAttachmentDownload(messageGuid, content);
      }
    }
  }

  /// Starts a download for [attachment] and wires it into [AttachmentState].
  void _startAttachmentDownload(String messageGuid, Attachment attachment) {
    final msgGuid = messageGuid;
    final attGuid = attachment.guid!;
    final ctrl = AttachmentDownloader.startDownload(attachment, onComplete: (PlatformFile file) {
      _onAttachmentDownloadComplete(msgGuid, attGuid, file);
    });

    final msgState = messageStates[messageGuid];
    if (msgState == null) return;

    final attState = msgState.getOrCreateAttachmentState(attGuid, attachment: attachment);
    attState.updateActiveDownloadInternal(ctrl);
    notifyAttachmentDownloadStarted(messageGuid, attGuid, ctrl);
  }

  /// Manually triggers a download for [attachment] (e.g., user tapped
  /// a not-loaded attachment).  The [messageGuid] must match the owning
  /// message's GUID.
  void startAttachmentDownload(String messageGuid, Attachment attachment) {
    _startAttachmentDownload(messageGuid, attachment);
  }

  /// Deletes the stale [AttachmentDownloadController] and restarts the
  /// download.  Called when the user taps a failed (error-state) attachment.
  void retryAttachmentDownload(String messageGuid, Attachment attachment) {
    if (attachment.guid != null) {
      AttachmentDownloader.clearControllerForGuid(attachment.guid!);
    }
    // Clear stale active-download reference before restarting.
    messageStates[messageGuid]?.getAttachmentState(attachment.guid!)?.updateActiveDownloadInternal(null);
    _startAttachmentDownload(messageGuid, attachment);
  }

  /// Deletes the local attachment files, resets the [AttachmentState] so the
  /// UI immediately shows the downloading UI, and starts a fresh download.
  ///
  /// Called when the user picks "Re-download from server".  Unlike a simple
  /// `attachmentRefreshKey` bump, this method explicitly clears `resolvedFile`
  /// and transitions the state to [AttachmentTransferState.downloading] so
  /// that [loadAttachmentContent]'s early-exit guards don't swallow the event.
  Future<void> redownloadAttachment(String messageGuid, Attachment attachment) async {
    final attGuid = attachment.guid;
    if (attGuid == null) return;

    // Hard reset any stale queued/completed controller before state wiring.
    AttachmentDownloader.clearControllerForGuid(attGuid);

    // 1. Reset the AttachmentState so the UI drops the resolved file
    //    immediately and shows the downloading widget instead.
    final attState = messageStates[messageGuid]?.getAttachmentState(attGuid);
    if (attState != null) {
      attState.updateResolvedFileInternal(null);
      attState.updateActiveDownloadInternal(null);
      attState.updateIsDownloadedInternal(false);
      attState.updateTransferStateInternal(AttachmentTransferState.idle);
    }

    // 2. Delete local files, reset DB flag, and register a new controller.
    try {
      await AttachmentsSvc.redownloadAttachment(attachment);
    } catch (e, s) {
      Logger.error('redownloadAttachment failed for $attGuid', error: e, trace: s, tag: 'MessagesService');
    }

    // 3. Wire the freshly created controller into the state machine so the
    //    Obx in AttachmentHolder rebuilds with DownloadingContent.
    final ctrl = AttachmentDownloader.getController(attGuid);
    if (ctrl != null) {
      notifyAttachmentDownloadStarted(messageGuid, attGuid, ctrl);
    } else {
      // Defensive fallback: ensure the re-download always starts.
      _startAttachmentDownload(messageGuid, attachment);
    }
  }

  // ========== End Attachment Download Orchestration ==========

  void init(Chat c, Function(Message) onNewMessage, Function(Message, {String? oldGuid}) onUpdatedMessage,
      Function(Message) onDeletedMessage, Function(String) jumpToMessageFunc, List<Message> messagesRef) {
    chat = c;
    Get.put<String>(tag, tag: 'lastReloadedChat');

    updateFunc = onUpdatedMessage;
    removeFunc = onDeletedMessage;
    newFunc = onNewMessage;
    jumpToMessage = jumpToMessageFunc;
    this.messagesRef = messagesRef;

    // watch for new messages (web only; native platforms use explicit addNewMessage calls)
    if (!_init) {
      if (kIsWeb) {
        _webMessageSub = WebListeners.newMessage.listen((tuple) {
          if (tuple.chat?.guid == chat.guid) {
            _handleNewMessage(tuple.message);
          }
        });
      }
    }
    _init = true;
    _setupRedactedModeListeners();
  }

  /// Set up global listeners for redacted mode settings that update all message states
  void _setupRedactedModeListeners() {
    // Cancel existing listeners if any
    _redactedModeListener?.cancel();
    _hideMessageContentListener?.cancel();
    _hideAttachmentsListener?.cancel();

    // Listen to redacted mode master toggle - when enabled, redact all messages; when disabled, unredact all
    _redactedModeListener = SettingsSvc.settings.redactedMode.listen((enabled) {
      for (final messageState in messageStates.values) {
        if (enabled) {
          messageState.redactFields();
        } else {
          messageState.unredactFields();
        }
      }
    });

    // Listen to hideMessageContent toggle - only affects message text/subject
    _hideMessageContentListener = SettingsSvc.settings.hideMessageContent.listen((enabled) {
      for (final messageState in messageStates.values) {
        if (enabled) {
          messageState.redactMessageContent();
        } else {
          messageState.unredactMessageContent();
        }
      }
    });

    // Listen to hideAttachments toggle - updates shouldHideAttachments on all message states
    _hideAttachmentsListener = SettingsSvc.settings.hideAttachments.listen((enabled) {
      final rm = SettingsSvc.settings.redactedMode.value;
      for (final messageState in messageStates.values) {
        messageState.updateShouldHideAttachmentsInternal(rm && enabled);
      }
    });
  }

  @override
  void onClose() {
    if (_init) {
      _webMessageSub?.cancel();
      _redactedModeListener?.cancel();
      _hideMessageContentListener?.cancel();
      _hideAttachmentsListener?.cancel();
    }
    _init = false;
    // Dispose all message states (attachment workers + web subscription)
    for (final messageState in messageStates.values) {
      messageState.onClose();
    }
    messageStates.clear();
    super.onClose();
  }

  void close({bool force = false}) {
    String? lastChat = lastReloadedChat();
    if (force || lastChat != tag) {
      Get.delete<MessagesService>(tag: tag, force: true);
    }

    struct.flush();
    messagesLoaded = false;
    messageUpdateTrigger.clear();
    for (final state in messageStates.values) {
      state.onClose();
    }
    messageStates.clear();
  }

  void reload() {
    messagesLoaded = false;
    Get.put<String>(tag, tag: 'lastReloadedChat');
    Get.reload<MessagesService>(tag: tag, force: true);
  }

  /// Adds [message] to the active chat view if it is not already present.
  /// Called by external synchronization paths (e.g. incremental sync) as an
  /// explicit dispatch that complements the ObjectBox watch-based flow.
  Future<void> addNewMessage(Message message) async {
    if (message.guid == null) return;
    if (struct.getMessage(message.guid!) != null) return;
    await _handleNewMessage(message);
  }

  Future<void> _handleNewMessage(Message message) async {
    // Add to struct first to ensure it's available for lookups
    struct.addMessages([message]);

    // Create or update MessageState for this message.
    // If it already exists (e.g. created by prepAttachment before the ObjectBox
    // watch fired), update the metadata rather than overwriting transfer states.
    if (message.guid != null) {
      if (!messageStates.containsKey(message.guid!)) {
        final state = MessageState(message);
        state.onInit();
        messageStates[message.guid!] = state;
        Logger.debug("Created MessageState for new message ${message.guid}", tag: "MessageState");
      } else {
        messageStates[message.guid!]!.updateFromMessage(message);
        Logger.debug("Updated existing MessageState for message ${message.guid}", tag: "MessageState");
      }
    }

    // Handle reactions with improved reactivity
    if (message.associatedMessageGuid != null) {
      final parentMessage = struct.getMessage(message.associatedMessageGuid!);
      if (parentMessage != null) {
        // Add to parent's associated messages list
        parentMessage.associatedMessages.add(message);

        // Update parent MessageState with the new reaction
        final parentState = messageStates[message.associatedMessageGuid!];
        if (parentState != null) {
          parentState.addAssociatedMessageInternal(message);
          Logger.debug("Added reaction ${message.guid} to MessageState of parent ${message.associatedMessageGuid}",
              tag: "MessageState");
        }

        // Notify UI of update (no longer need to call controller methods)
        triggerMessageUpdate(message.associatedMessageGuid!);
      } else {
        Logger.warn("Parent message not found for reaction ${message.guid} (parent: ${message.associatedMessageGuid})",
            tag: "MessageReactivity");
      }
    }

    // Handle thread originators with improved reactivity
    if (message.threadOriginatorGuid != null) {
      // Update thread originator MessageState
      final originatorState = messageStates[message.threadOriginatorGuid!];
      if (originatorState != null) {
        final currentCount = originatorState.threadReplyCount.value;
        originatorState.updateThreadReplyCountInternal(currentCount + 1);
        Logger.debug("Incremented thread reply count for ${message.threadOriginatorGuid} to ${currentCount + 1}",
            tag: "MessageState");
      }

      // Notify UI of update
      triggerMessageUpdate(message.threadOriginatorGuid!);
    }

    // Only call newFunc for non-reactions (regular messages)
    if (message.associatedMessageGuid == null) {
      newFunc.call(message);
    }

    // Incrementally update indicator ownership for new outgoing messages.
    // Reactions don't carry receipt status so skip them.
    if (message.associatedMessageGuid == null) {
      _updateIndicatorsForMessage(message);
    }
  }

  void updateMessage(Message updated, {String? oldGuid}) {
    // Try to find the message - check oldGuid first, then fallback to updated.guid
    // This handles race conditions where the GUID was already replaced
    Message? toUpdate;
    if (oldGuid != null) {
      toUpdate = struct.getMessage(oldGuid);
    }
    toUpdate ??= struct.getMessage(updated.guid!);
    if (toUpdate == null) return;

    // Capture the previous edit date BEFORE the merge/updateFromMessage below.
    // toUpdate is the *same* Message instance held by messageState.message, so
    // updateFromMessage() mutates toUpdate.dateEdited in place — comparing
    // against toUpdate after that point would always be equal and the
    // buildMessageParts guard would never fire. See the guard below.
    final previousDateEdited = toUpdate.dateEdited;
    final previousDateDeleted = toUpdate.dateDeleted;

    // Preserve authoritative fields before merging — Message.merge is written for
    // existing(older).merge(newMessage(newer)), but here we call it inverted:
    // `updated` is the authoritative new state and `toUpdate` is the stale struct
    // copy. Merge would copy stale error/attributedBody/messageSummaryInfo from
    // toUpdate onto updated, reverting server-side edits/retractions in memory
    // (the DB write path handles this correctly, which is why re-entering the
    // chat shows the right thing). Snapshot and restore the incoming values.
    final incomingError = updated.error;
    final incomingErrorMessage = updated.errorMessage;
    final incomingAttributedBody = updated.attributedBody;
    final incomingSummaryInfo = updated.messageSummaryInfo;
    final incomingPayloadData = updated.payloadData;
    updated = updated.mergeWith(toUpdate);
    updated.error = incomingError;
    updated.errorMessage = incomingErrorMessage;
    if (incomingAttributedBody.isNotEmpty) updated.attributedBody = incomingAttributedBody;
    if (incomingSummaryInfo.isNotEmpty) updated.messageSummaryInfo = incomingSummaryInfo;
    if (incomingPayloadData != null) updated.payloadData = incomingPayloadData;
    struct.removeMessage(oldGuid ?? updated.guid!);
    struct.removeAttachments(toUpdate.dbAttachments.map((e) => e.guid!));
    struct.addMessages([updated]);

    // Update MessageState - try oldGuid first, then fallback to updated.guid
    MessageState? messageState;
    if (oldGuid != null) {
      messageState = messageStates[oldGuid];
    }
    messageState ??= messageStates[updated.guid!];

    if (messageState != null) {
      messageState.updateFromMessage(updated);
      Logger.debug("Updated MessageState for message ${updated.guid}", tag: "MessageState");

      // If dateEdited changed, messageSummaryInfo has new edit/retraction data.
      // Force-rebuild parts so isUnsent flags and edit history reflect the update.
      // This mirrors the `hasEdited` check in MessageState.updateMessage (web path).
      // Compare against previousDateEdited (snapshotted above) rather than
      // toUpdate.dateEdited — updateFromMessage() just mutated toUpdate in place.
      if (updated.dateEdited != previousDateEdited || updated.dateDeleted != previousDateDeleted) {
        messageState.buildMessageParts(force: true);
      }

      // If guid changed (temp -> real), update the map
      if (oldGuid != null && oldGuid != updated.guid) {
        messageStates.remove(oldGuid);
        if (updated.guid != null) {
          messageStates[updated.guid!] = messageState;
          Logger.debug("Moved MessageState from $oldGuid to ${updated.guid}", tag: "MessageState");
        }

        // Notify the state to merge the new message reference and rebuild parts.
        // notifyGuidSwap avoids re-entering this method.
        messageState.notifyGuidSwap(updated);

        // Keep tracking refs consistent with the new key so that
        // _updateIndicatorsForMessage targets the correct messageStates entry.
        _renameIndicatorTracking(oldGuid, updated.guid!);
      }
    } else if (updated.guid != null) {
      // State doesn't exist, create it
      final state = MessageState(updated);
      state.onInit();
      messageStates[updated.guid!] = state;
    }

    // Trigger granular update for this specific message
    messageUpdateTrigger[updated.guid!] = DateTime.now().millisecondsSinceEpoch;

    // Incrementally update indicator ownership; dates or GUID may have changed.
    _updateIndicatorsForMessage(updated);

    updateFunc.call(updated, oldGuid: oldGuid);
  }

  void removeMessage(Message toRemove) {
    struct.removeMessage(toRemove.guid!);
    struct.removeAttachments(toRemove.dbAttachments.map((e) => e.guid!));
    messageUpdateTrigger.remove(toRemove.guid!);

    // Dispose attachment states and remove MessageState
    messageStates.remove(toRemove.guid!)?.onClose();
    Logger.debug("Removed MessageState for message ${toRemove.guid}", tag: "MessageState");

    // Recompute indicator ownership after the message is gone.
    _recomputeDeliveredIndicators();

    removeFunc.call(toRemove);
  }

  /// Check if a specific message has been updated (for granular Obx widgets)
  bool isMessageUpdated(String guid) {
    return messageUpdateTrigger.containsKey(guid);
  }

  /// Trigger an update for a specific message (useful for reactions, read receipts, etc.)
  void triggerMessageUpdate(String guid) {
    messageUpdateTrigger[guid] = DateTime.now().millisecondsSinceEpoch;
  }

  /// Clear the update flag for a message after it's been processed
  void clearMessageUpdate(String guid) {
    messageUpdateTrigger.remove(guid);
  }

  // ========== Delivered Indicator Recomputation ==========

  /// Renames tracking refs when a message GUID changes (temp → real).
  /// Must be called BEFORE [_updateIndicatorsForMessage] on the same update
  /// so that the tracking fields stay consistent with [messageStates] keys.
  void _renameIndicatorTracking(String oldGuid, String newGuid) {
    if (_lastReadInfo?.guid == oldGuid) {
      _lastReadInfo = MessageReceiptInfo(newGuid, date: _lastReadInfo!.date, createdDate: _lastReadInfo!.createdDate);
    }
    if (_lastDeliveredInfo?.guid == oldGuid) {
      _lastDeliveredInfo =
          MessageReceiptInfo(newGuid, date: _lastDeliveredInfo!.date, createdDate: _lastDeliveredInfo!.createdDate);
    }
  }

  /// Incrementally updates indicator ownership for a single outgoing [message].
  ///
  /// Used on [_handleNewMessage] and [updateMessage].  Avoids a full list scan
  /// by comparing the incoming message's tier-relevant date against the stored
  /// tracking info:
  /// - **Read**: compares [Message.dateRead] vs stored date (also dateRead).
  /// - **Delivered**: compares [Message.dateDelivered] vs stored date; when
  ///   [Message.isDelivered] is true but no timestamp is present, falls back
  ///   to [Message.dateCreated] compared against whatever date the current
  ///   owner stored.
  ///
  /// Only outgoing (isFromMe == true) messages participate in any indicator tier.
  void _updateIndicatorsForMessage(Message message) {
    if (message.isFromMe != true || message.guid == null) return;

    final guid = message.guid!;

    // Helper: returns true when [candidate] is strictly newer than [stored].
    bool isNewer(DateTime? candidate, DateTime? stored) {
      if (candidate == null) return false;
      if (stored == null) return true;
      return candidate.isAfter(stored);
    }

    // ---- Read tier: compare by dateRead ----
    if (message.dateRead != null) {
      final current = _lastReadInfo;
      if (current?.guid != guid && isNewer(message.dateRead, current?.date)) {
        messageStates[current?.guid]?.updateShowReadIndicatorInternal(false);
        _lastReadInfo = MessageReceiptInfo(guid, date: message.dateRead, createdDate: message.dateCreated);
        messageStates[guid]?.updateShowReadIndicatorInternal(true);
      }
    }

    // ---- Delivered tier: qualifies only when delivered but NOT yet read.  ----
    //      A message that gains dateRead exits the delivered tier so the next
    //      most-recently-delivered (unread) message takes over.
    final hasDelivered = message.dateDelivered != null || message.isDelivered;
    if (hasDelivered && message.dateRead == null) {
      final effectiveDate = message.dateDelivered ?? message.dateCreated;
      final current = _lastDeliveredInfo;
      if (current?.guid != guid && isNewer(effectiveDate, current?.date)) {
        messageStates[current?.guid]?.updateShowDeliveredIndicatorInternal(false);
        _lastDeliveredInfo = MessageReceiptInfo(guid, date: effectiveDate, createdDate: message.dateCreated);
        messageStates[guid]?.updateShowDeliveredIndicatorInternal(true);
      }
    } else if (message.dateRead != null && _lastDeliveredInfo?.guid == guid) {
      // This message was the delivered-tier owner but has now been read.
      // Clear its delivered flag and find the next eligible message.
      messageStates[guid]?.updateShowDeliveredIndicatorInternal(false);
      _lastDeliveredInfo = null;
      _recomputeDeliveredIndicator();
    }

    _normalizeDeliveredVsRead();
  }

  /// Targeted rescan for the delivered tier only.  Called when the previous
  /// delivered-tier owner gains a read receipt and we need to find the next
  /// newest delivered-but-not-read message.
  void _recomputeDeliveredIndicator() {
    Message? best;
    DateTime? bestDate;
    for (final m in struct.messages.where((e) => e.isFromMe == true)) {
      if ((m.dateDelivered == null && !m.isDelivered) || m.dateRead != null) continue;
      final effectiveDate = m.dateDelivered ?? m.dateCreated;
      if (best == null || (effectiveDate != null && (bestDate == null || effectiveDate.isAfter(bestDate)))) {
        best = m;
        bestDate = effectiveDate;
      }
    }
    if (best?.guid != null) {
      _lastDeliveredInfo = MessageReceiptInfo(best!.guid!, date: bestDate, createdDate: best.dateCreated);
      messageStates[best.guid!]?.updateShowDeliveredIndicatorInternal(true);
    }
    _normalizeDeliveredVsRead();
  }

  /// Suppresses or re-enables the delivered indicator based on whether a newer
  /// read message exists.  A read receipt on a newer (or same-age) message
  /// supersedes any older "Delivered" label.  Call this after updating either
  /// the read or delivered tier so the flag always reflects cross-tier state.
  void _normalizeDeliveredVsRead() {
    if (_lastDeliveredInfo == null) return;
    final bool shouldShow;
    if (_lastReadInfo == null) {
      shouldShow = true;
    } else {
      final readCreated = _lastReadInfo!.createdDate;
      final deliveredCreated = _lastDeliveredInfo!.createdDate;
      // Show delivered only if it is strictly newer than the read message.
      // When dates are unavailable, the read message wins (hide delivered).
      shouldShow = readCreated != null && deliveredCreated != null && deliveredCreated.isAfter(readCreated);
    }
    messageStates[_lastDeliveredInfo!.guid]?.updateShowDeliveredIndicatorInternal(shouldShow);
  }

  /// Full two-tier recompute across all loaded outgoing messages.
  ///
  /// Used on initial load ([loadChunk] / [loadSearchChunk]) and on [removeMessage]
  /// when the removed message may have been an indicator owner.  Prefer
  /// [_updateIndicatorsForMessage] for add/update events.
  void _recomputeDeliveredIndicators() {
    final outgoing = struct.messages.where((e) => e.isFromMe == true).toList()..sort(Message.sort);

    // ---- Read tier: find message with newest dateRead ----
    Message? newLastRead;
    for (final m in outgoing) {
      if (m.dateRead == null) continue;
      if (newLastRead == null || m.dateRead!.isAfter(newLastRead.dateRead!)) newLastRead = m;
    }
    if (newLastRead?.guid != _lastReadInfo?.guid) {
      messageStates[_lastReadInfo?.guid]?.updateShowReadIndicatorInternal(false);
      _lastReadInfo = newLastRead != null
          ? MessageReceiptInfo(newLastRead.guid!, date: newLastRead.dateRead, createdDate: newLastRead.dateCreated)
          : null;
      if (_lastReadInfo != null) messageStates[_lastReadInfo!.guid]?.updateShowReadIndicatorInternal(true);
    }

    // ---- Delivered tier: find message with newest effective delivery date.
    //      Only considers messages that are delivered but NOT yet read — a read
    //      message should exit the delivered tier so the read tier owns it. ----
    Message? newLastDelivered;
    DateTime? newLastDeliveredDate;
    for (final m in outgoing) {
      if ((m.dateDelivered == null && !m.isDelivered) || m.dateRead != null) continue;
      final effectiveDate = m.dateDelivered ?? m.dateCreated;
      if (newLastDelivered == null ||
          (effectiveDate != null && (newLastDeliveredDate == null || effectiveDate.isAfter(newLastDeliveredDate)))) {
        newLastDelivered = m;
        newLastDeliveredDate = effectiveDate;
      }
    }
    if (newLastDelivered?.guid != _lastDeliveredInfo?.guid) {
      messageStates[_lastDeliveredInfo?.guid]?.updateShowDeliveredIndicatorInternal(false);
      _lastDeliveredInfo = newLastDelivered != null
          ? MessageReceiptInfo(newLastDelivered.guid!,
              date: newLastDeliveredDate, createdDate: newLastDelivered.dateCreated)
          : null;
      if (_lastDeliveredInfo != null) {
        messageStates[_lastDeliveredInfo!.guid]?.updateShowDeliveredIndicatorInternal(true);
      }
    }

    _normalizeDeliveredVsRead();
  }

  // ========== End Delivered Indicator Recomputation ==========

  /// Generates new temp GUID, clears error state, and updates both DB and MessageState
  Future<void> retryFailedMessage(Message message, {String? oldGuid}) async {
    final guidToDelete = oldGuid ?? message.guid!;

    // Generate new temp GUID for retry
    message.generateTempGuid();

    // Clear error and delivery status
    message.error = 0;
    message.errorMessage = null;
    message.dateCreated = DateTime.now();
    message.dateDelivered = null;
    message.dateRead = null;

    // Delete old errored message from DB and save with new temp GUID
    await Message.delete(guidToDelete);
    message.id = null;
    message.save(chat: chat);

    // Update struct using the proper map API (struct.messages returns a copy, not the backing map)
    struct.removeMessage(guidToDelete);
    struct.addMessages([message]);

    // Always update the UI entry in-place first so error decorations are
    // immediately cleared, regardless of position.  updateFunc swaps the old
    // guid entry in _messages for the new temp message object at the same
    // list index.
    updateFunc(message, oldGuid: guidToDelete);

    // For non-last messages the date is now newer than the surrounding entries,
    // so remove the freshly-placed entry and re-insert it at the sorted
    // position.  removeFunc works correctly after updateFunc because the new
    // guid is now present in _messages.
    if (messagesRef.isNotEmpty && messagesRef.last.guid != guidToDelete) {
      removeFunc(message);
      newFunc(message);
    }

    // Re-key the existing MessageState under the new temp GUID instead of
    // discarding it.  Attachment widgets capture a direct reference to their
    // MessageState in initState() via MessageStateScope.readStateOnce() and
    // never re-resolve it; keeping the same object in memory means that
    // existing Obx subscriptions on AttachmentState react to the in-place
    // resetForRetryInternal() call below and immediately show upload progress.
    // If no prior state exists (e.g. user navigated away during error), fall
    // back to creating a fresh one as before.
    final existingState = messageStates.remove(guidToDelete);
    final MessageState messageState;
    if (existingState != null) {
      messageStates[message.guid!] = existingState;
      messageState = existingState;
    } else {
      messageState = getOrCreateMessageState(message.guid!);
    }
    messageState.updateErrorInternal(0);
    messageState.updateErrorMessageInternal(null);
    messageState.updateDateCreatedInternal(message.dateCreated);
    messageState.updateDateDeliveredInternal(null);
    messageState.updateDateReadInternal(null);

    // Clear notification
    await NotificationsSvc.clearFailedToSend(chat.id!);

    // Reload attachment bytes and synchronise the attachment GUID with the
    // new message GUID so that:
    //   (a) the server's socket echo carries a tempGuid that exists in the DB
    //       (preventing a spurious duplicate message in the list), and
    //   (b) the attachment progress / state map keys stay consistent across
    //       prepAttachment → sendAttachment → onSuccess/onError.
    // The attachment.guid == message.guid invariant is established in
    // send_animation.dart for initial sends; we must restore it on retry.
    for (Attachment? a in message.dbAttachments) {
      if (a == null) continue;
      final oldAttGuid = a.guid!;

      // Read bytes while the file is still at the old (pre-rename) path.
      a.bytes = await File(a.path).readAsBytes();

      // Move the attachment directory so the file is immediately accessible
      // at the new guid-based path.  This lets _restoreInFlightAttachmentStates
      // populate uploadPreviewFile even before prepAttachment runs.
      if (!kIsWeb) {
        final oldDir = Directory("${Attachment.baseDirectory}/$oldAttGuid");
        final newDir = Directory("${Attachment.baseDirectory}/${message.guid}");
        if (oldDir.existsSync() && !newDir.existsSync()) {
          oldDir.renameSync(newDir.path);
        }
      }

      // Sync attachment GUID with the new temp message GUID.
      a.guid = message.guid;

      // Persist the updated GUID to DB immediately (in-place update via
      // existing ObjectBox ID).  Without this there is a window between
      // retryFailedMessage returning and prepAttachment's c.addMessage call
      // where message.dbAttachments is empty, causing _restoreInFlightAttachmentStates
      // to skip the message on re-entry and the progress overlay to never show.
      await a.saveAsync(message);

      // Pre-register in attachmentProgress so _restoreInFlightAttachmentStates
      // finds the entry the moment the user re-enters, even before prepAttachment
      // runs its own add.  prepAttachment will add a second entry for the same
      // guid; both are cleaned up together by the removeWhere in onSuccess/onError.
      if (!OutgoingMsgHandler.attachmentProgress.any((e) => e.guid == message.guid)) {
        OutgoingMsgHandler.attachmentProgress.add(AttachmentUploadProgress(message.guid!, 0.0.obs));
      }

      // Reset the existing AttachmentState in-place (re-key + uploading transition)
      // so the widget's Obx sees isSending=true without needing a full rebuild.
      final attState = messageState.attachmentStates.remove(oldAttGuid);
      if (attState != null) {
        attState.resetForRetryInternal(message.guid!);
        messageState.attachmentStates[message.guid!] = attState;
      }
    }

    // Queue for sending (message already in UI, just updated)
    if (message.dbAttachments.isNotEmpty) {
      OutgoingMsgHandler.queue(
        OutgoingAttachment(
          chat: chat,
          message: message,
          attachment: message.dbAttachments.first,
          isAudioMessage: message.itemType == 5,
          isRetry: true,
        ),
      );
    } else {
      OutgoingMsgHandler.queue(
        OutgoingMessage(
          chat: chat,
          message: message,
          isRetry: true,
        ),
      );
    }

    // The retried message always gets dateCreated = now, making it the newest
    // message in the chat regardless of what was previously the latest.
    // Always update the chat's latest message, subtitle, and sort position.
    ChatsSvc.updateChatLatestMessage(tag, message);
  }

  /// Delete a message from DB, struct, and MessageState.
  /// If the deleted message was the chat's latest, updates the chat's latest message
  /// in both the database and reactive state.
  Future<void> deleteMessage(Message message) async {
    final deletedGuid = message.guid!;
    await Message.delete(deletedGuid);
    removeMessage(message);
    await _updateLatestMessageAfterDeletion(deletedGuid);
  }

  /// Soft-delete a message (sets dateDeleted) and remove it from the struct and MessageState.
  /// If the deleted message was the chat's latest, updates the chat's latest message
  /// in both the database and reactive state.
  Future<void> softDeleteMessage(Message message) async {
    final deletedGuid = message.guid!;
    await Message.softDelete(deletedGuid);
    removeMessage(message);
    await _updateLatestMessageAfterDeletion(deletedGuid);
  }

  /// If [deletedGuid] was the chat's latest message, fetches the new latest from the
  /// database and updates both [ChatState] and the [Chat] DB record.
  Future<void> _updateLatestMessageAfterDeletion(String deletedGuid) async {
    if (kIsWeb) return;
    final chatState = ChatsSvc.getChatState(tag);
    if (chatState == null || chatState.latestMessage.value?.guid != deletedGuid) return;
    final chat = ChatsSvc.findChatByGuid(tag);
    if (chat == null) return;
    final latest = Chat.getMessages(chat, limit: 1);
    if (latest.isNotEmpty) {
      // The newest message was just deleted, so the surviving latest is older
      // than the current pointer — allow the downgrade here specifically.
      ChatsSvc.updateChatLatestMessage(tag, latest.first, allowOlder: true);
    }
  }

  /// Toggle bookmark status on a message
  /// Updates DB and MessageState
  void toggleBookmark(Message message) {
    message.isBookmarked = !message.isBookmarked;
    message.save(updateIsBookmarked: true);

    // Update MessageState if it exists
    final messageState = getMessageStateIfExists(message.guid!);
    messageState?.updateIsBookmarkedInternal(message.isBookmarked);
  }

  /// Edits the text of [partIndex] on [message] and updates the UI reactively.
  ///
  /// [MessageState] is optional — the edit is attempted regardless of whether
  /// one exists. If it does exist, the UI is updated optimistically before the
  /// request and reverted on failure. The state is re-fetched after the async
  /// gap because it may have been disposed while the request was in flight.
  ///
  /// Flow:
  ///   1. If [MessageState] exists: optimistically update [MessagePart.text].
  ///   2. Call the edit API.
  ///   3. On success: route the server's authoritative response through
  ///      [IncomingMsgHandler] so [updateMessage] patches the [MessageState]
  ///      with the real [messageSummaryInfo] (edit history, etc.) and persists
  ///      to the DB.
  ///   4. On failure: if [MessageState] still exists, revert the optimistic
  ///      text and set [ClientMessageError.editFailed] (10006).
  Future<void> editMessage(Message message, int partIndex, String newText) async {
    final messageGuid = message.guid;
    if (messageGuid == null) return;

    // --- Optional optimistic update (state may not exist) ---
    final preState = getMessageStateIfExists(messageGuid);
    final partIdx = preState?.parts.indexWhere((p) => p.part == partIndex) ?? -1;
    final String? originalText = partIdx >= 0 ? preState!.parts[partIdx].text : null;
    final DateTime? originalDateEdited = preState?.dateEdited.value;
    if (preState != null) {
      if (partIdx >= 0) {
        preState.parts[partIdx].text = newText;
        preState.parts.refresh();
      }

      preState.updateDateEditedInternal(DateTime.now().toUtc());

      // Clear any stale edit error from a previous attempt.
      preState.updateErrorInternal(0);
      preState.updateErrorMessageInternal(null);
    }

    try {
      final response = await HttpSvc.message.edit(
        messageGuid,
        newText,
        "Edited to: '$newText'",
        partIndex: partIndex,
      );
      // response is always HTTP 200 here — returnSuccessOrError converts
      // non-200 into Future.error, which is caught below.
      final updatedMessage = Message.fromMap(response.data['data']);
      IncomingMsgHandler.handle(IncomingPayload(
        type: MessageEventType.updatedMessage,
        source: MessageSource.apiResponse,
        chat: chat,
        message: updatedMessage,
      ));
    } catch (ex, stack) {
      Logger.error("Failed to edit message $messageGuid", error: ex, trace: stack, tag: "MessagesService");

      // Re-fetch state — it may have been disposed while the request was in flight.
      final postState = getMessageStateIfExists(messageGuid);
      if (postState != null) {
        // Revert the optimistic text and dateEdited changes so the user sees the original content.
        if (partIdx >= 0 && originalText != null) {
          postState.parts[partIdx].text = originalText;
          postState.parts.refresh();
        }
        postState.updateDateEditedInternal(originalDateEdited);

        // Derive a human-readable reason from the caught value.
        final String reason;
        if (ex is Response) {
          final serverMsg = ex.data?['error']?['message'] as String?;
          reason = serverMsg ?? "Server returned ${ex.statusCode}";
        } else {
          reason = ex.toString();
        }

        postState.updateErrorInternal(ClientMessageError.editFailed.code); //
        postState.updateErrorMessageInternal("Failed to edit message: $reason");
      }
    }
  }

  /// Unsends (retracts) [partIndex] on [message] and updates the UI reactively.
  ///
  /// [MessageState] is optional — the unsend is attempted regardless of whether
  /// one exists. If it does exist, the UI is updated optimistically before the
  /// request and reverted on failure. The state is re-fetched after the async
  /// gap because it may have been disposed while the request was in flight.
  ///
  /// Flow:
  ///   1. If [MessageState] exists: optimistically mark the part as unsent and
  ///      set [dateEdited] to now.
  ///   2. Call the unsend API.
  ///   3. On success: route the server's authoritative response through
  ///      [IncomingMsgHandler], then force-rebuild parts so [retractedParts] /
  ///      [isFullyUnsent] / [isPartiallyUnsent] reflect the true server state.
  ///   4. On failure: if [MessageState] still exists, revert the optimistic
  ///      changes and set [ClientMessageError.unsendFailed] (10007).
  Future<void> unsendMessage(Message message, int partIndex) async {
    final messageGuid = message.guid;
    if (messageGuid == null) return;

    // --- Optional optimistic update (state may not exist) ---
    final preState = getMessageStateIfExists(messageGuid);
    final partIdx = preState?.parts.indexWhere((p) => p.part == partIndex) ?? -1;
    final DateTime? originalDateEdited = preState?.dateEdited.value;
    final bool originalIsUnsent = partIdx >= 0 ? (preState!.parts[partIdx].isUnsent) : false;
    if (preState != null) {
      if (partIdx >= 0) {
        preState.parts[partIdx].isUnsent = true;
        preState.parts.refresh();
      }

      preState.updateDateEditedInternal(DateTime.now().toUtc());

      // Clear any stale error from a previous attempt.
      preState.updateErrorInternal(0);
      preState.updateErrorMessageInternal(null);
    }

    try {
      final response = await HttpSvc.message.unsend(messageGuid, partIndex: partIndex);
      final updatedMessage = Message.fromMap(response.data['data']);
      // Await the handler — it processes on an async FIFO queue, so firing and
      // forgetting would let the buildMessageParts below run against a message
      // whose messageSummaryInfo hasn't been updated yet, wiping the optimistic
      // unsent flag and briefly showing the message again. Awaiting lets
      // updateMessage() rebuild parts once with the authoritative server state.
      await IncomingMsgHandler.handle(IncomingPayload(
        type: MessageEventType.updatedMessage,
        source: MessageSource.apiResponse,
        chat: chat,
        message: updatedMessage,
      ));

      // Re-fetch state and force-rebuild parts so reactive getters (isFullyUnsent,
      // isPartiallyUnsent, retractedParts) reflect the server response.
      final postSuccessState = getMessageStateIfExists(messageGuid);
      postSuccessState?.buildMessageParts(force: true);
    } catch (ex, stack) {
      Logger.error("Failed to unsend message $messageGuid", error: ex, trace: stack, tag: "MessagesService");

      // Re-fetch state — it may have been disposed while the request was in flight.
      final postState = getMessageStateIfExists(messageGuid);
      if (postState != null) {
        // Revert the optimistic changes.
        if (partIdx >= 0) {
          postState.parts[partIdx].isUnsent = originalIsUnsent;
          postState.parts.refresh();
        }
        postState.updateDateEditedInternal(originalDateEdited);

        // Derive a human-readable reason from the caught value.
        final String reason;
        if (ex is Response) {
          final serverMsg = ex.data?['error']?['message'] as String?;
          reason = serverMsg ?? "Server returned ${ex.statusCode}";
        } else {
          reason = ex.toString();
        }

        postState.updateErrorInternal(ClientMessageError.unsendFailed.code);
        postState.updateErrorMessageInternal("Failed to unsend message: $reason");
      }
    }
  }

  Future<bool> loadChunk(int offset, ConversationViewController controller, {int limit = 25}) async {
    List<Message> _messages = [];

    // Adjust offset because reactions _are_ messages. We just separate them out in the struct.
    offset = offset + struct.reactions.length;

    try {
      Logger.debug("[loadChunk] Starting to load messages (offset: $offset, limit: $limit)", tag: "MessageReactivity");

      _messages = await Chat.getMessagesAsync(
        chat,
        offset: offset,
        limit: limit,
        onSupplementalDataLoaded: () {
          // Phase 2 complete - reactions have been loaded into message.associatedMessages
          Logger.info("[loadChunk] Supplemental data loaded, syncing MessageStates for ${_messages.length} messages",
              tag: "MessageReactivity");

          // Ensure MessageStates exist first (in case they weren't created yet)
          _ensureMessageStates(_messages);

          // Sync associatedMessages into MessageState observables
          for (final message in _messages) {
            if (message.guid != null && message.associatedMessages.isNotEmpty) {
              final messageState = messageStates[message.guid];
              if (messageState != null) {
                // Clear and repopulate the observable list to trigger reactivity
                messageState.associatedMessages.clear();
                messageState.associatedMessages.addAll(message.associatedMessages);
                messageState.hasReactions.value = message.associatedMessages.isNotEmpty;

                Logger.debug(
                    "[loadChunk] Synced ${message.associatedMessages.length} reactions into MessageState for ${message.guid}",
                    tag: "MessageReactivity");
              }
            }
          }
        },
      );

      Logger.debug("[loadChunk] Loaded ${_messages.length} messages from local DB");
      if (_messages.isEmpty) {
        // get from server and save
        final fromServer = await ChatsSvc.getMessages(chat.guid, offset: offset, limit: limit);
        final rawMessages = fromServer.cast<Map<String, dynamic>>();
        final syncResult = await SyncInterface.bulkSyncData(
          chatData: chat.toMap(),
          messagesData: rawMessages,
        );
        if (!kIsWeb) {
          // Prefer the bulk-loaded list (already hydrated via getMany on the main thread)
          // over a second link-query, which can return 0 for newly-created chats whose
          // chat.targetId index hasn't yet been flushed to the read snapshot.
          // If temp is empty (bulk add found nothing new) fall back to the link query.
          if (syncResult.messages.isNotEmpty) {
            _messages = syncResult.messages;
          } else {
            _messages = await Chat.getMessagesAsync(chat, offset: offset, limit: limit);
          }

          // Sync the chat's latestMessage into ChatState after the server fetch.
          // Guards:
          // 1. offset == 0: only the first (newest) page should affect latestMessage.
          //    Loading older pages must never overwrite a newer latest.
          // 2. Use ChatState.latestMessage.value (the Rxn<Message>) for the comparison,
          //    NOT chat.latestMessage.  The Chat.latestMessage getter falls back to
          //    dbLatestMessage when _latestMessage is null, which queries the DB — and at
          //    this point the DB now contains the just-bulk-added old messages, so that
          //    query returns a stale old date and defeats the freshness check entirely.
          if (offset == 0) {
            for (final updatedChat in syncResult.chats) {
              final state = ChatsSvc.getChatState(updatedChat.guid);
              if (state != null && updatedChat.dbLatestMessage.target?.dateCreated != null) {
                final currentDate = state.latestMessage.value?.dateCreated;
                final hasRealCurrent = currentDate != null && currentDate.millisecondsSinceEpoch > 0;
                final latestMsg = updatedChat.dbLatestMessage.target;
                if (latestMsg != null &&
                    (!hasRealCurrent ||
                        (latestMsg.dateCreated != null && latestMsg.dateCreated!.isAfter(currentDate) == true))) {
                  ChatsSvc.updateChatLatestMessage(updatedChat.guid, latestMsg);
                }
              }
            }
          }
        } else {
          final reactions = syncResult.messages.where((e) => e.associatedMessageGuid != null);
          for (Message m in reactions) {
            final associatedMessage =
                syncResult.messages.firstWhereOrNull((element) => element.guid == m.associatedMessageGuid);
            associatedMessage?.hasReactions = true;
            associatedMessage?.associatedMessages.add(m);
          }
          _messages = syncResult.messages;
        }
      }
    } catch (e, s) {
      return Future.error(e, s);
    }

    struct.addMessages(_messages);

    // Create MessageStates for all loaded messages
    _ensureMessageStates(_messages);
    Logger.debug("[loadChunk] Created MessageStates for ${_messages.length} messages", tag: "MessageState");

    // Compute initial delivered indicator ownership after messages are loaded.
    _recomputeDeliveredIndicators();

    // get thread originators
    for (Message m in _messages.where((e) => e.threadOriginatorGuid != null)) {
      // see if the originator is already loaded
      final guid = m.threadOriginatorGuid!;
      if (struct.getMessage(guid) != null) continue;
      // if not, fetch local and add to data
      final threadOriginator = Message.findOne(guid: guid);
      if (threadOriginator != null) {
        // create the state so it can be rendered in a reply bubble
        final c = getOrCreateState(threadOriginator);
        c.cvController = controller;
        struct.addThreadOriginator(threadOriginator);
      }
    }

    // this indicates an audio message was kept by the recipient
    // run this every time more messages are loaded just in case
    for (Message m in struct.messages.where((e) => e.itemType == 5 && e.subject != null)) {
      final otherMessage = struct.getMessage(m.subject!);
      if (otherMessage != null) {
        final otherMwc = getMessageStateIfExists(m.subject!) ?? getOrCreateState(otherMessage);
        otherMwc.audioWasKept.value = m.dateCreated;
      }
    }

    messagesLoaded = true;
    return _messages.isNotEmpty;
  }

  Future<void> loadSearchChunk(Message around, SearchMethod method) async {
    List<Message> _messages = [];
    if (method == SearchMethod.local) {
      _messages = await Chat.getMessagesAsync(chat, searchAround: around.dateCreated!.millisecondsSinceEpoch);
      _messages.add(around);
      _messages.sort(Message.sort);
      struct.addMessages(_messages);
      // Create MessageStates for loaded messages
      _ensureMessageStates(_messages);
    } else {
      final beforeResponse = await ChatsSvc.getMessages(
        chat.guid,
        limit: 25,
        before: around.dateCreated!.millisecondsSinceEpoch,
      );
      final afterResponse = await ChatsSvc.getMessages(
        chat.guid,
        limit: 25,
        sort: "ASC",
        after: around.dateCreated!.millisecondsSinceEpoch,
      );
      beforeResponse.addAll(afterResponse);
      _messages = beforeResponse.map((e) => Message.fromMap(e)).toList();
      _messages.sort(Message.sort);
      struct.addMessages(_messages);
      // Create MessageStates for loaded messages
      _ensureMessageStates(_messages);
    }
    _recomputeDeliveredIndicators();
  }

  static Future<List<dynamic>> getMessages(
      {bool withChats = false,
      bool withAttachments = false,
      bool withHandles = false,
      bool withChatParticipants = false,
      List<dynamic> where = const [],
      String sort = "DESC",
      int? before,
      int? after,
      String? chatGuid,
      int offset = 0,
      int limit = 100}) async {
    Completer<List<dynamic>> completer = Completer();
    final withQuery = <String>["attributedBody", "messageSummaryInfo", "payloadData"];
    if (withChats) withQuery.add("chat");
    if (withAttachments) withQuery.add("attachment");
    if (withHandles) withQuery.add("handle");
    if (withChatParticipants) withQuery.add("chat.participants");
    withQuery.add("attachment.metadata");

    HttpSvc.message
        .query(
            withQuery: withQuery,
            where: where,
            sort: sort,
            before: before,
            after: after,
            chatGuid: chatGuid,
            offset: offset,
            limit: limit)
        .then((response) {
      if (!completer.isCompleted) completer.complete(response.data["data"]);
    }).catchError((err) {
      late final dynamic error;
      if (err is Response) {
        error = err.data["error"]["message"];
      } else {
        error = err?.toString();
      }
      if (!completer.isCompleted) completer.completeError(error ?? "");
    });

    return completer.future;
  }
}
