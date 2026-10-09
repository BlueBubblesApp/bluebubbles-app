import 'dart:async';

import 'package:bluebubbles/app/state/attachment_state.dart';
import 'package:bluebubbles/app/state/handle_state.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// State wrapper for Message that provides granular reactivity for UI components.
/// Each field that may affect the UI is tracked separately, allowing widgets
/// to observe only the specific properties they care about.
///
/// This pattern mirrors ChatState and provides:
/// - Single source of truth for message state
/// - Granular observables instead of boolean toggle flags
/// - Direct property updates instead of coordinator timestamps
/// - Type-safe state changes
class MessageState extends StatefulController {
  /// Reference to the underlying message object
  Message message;

  /// Reactive state objects for each attachment on this message.
  /// Keyed by attachment GUID.  Created eagerly in the constructor for any
  /// attachments already present on [message], and populated incrementally as
  /// new attachments are added or GUIDs are swapped.
  ///
  /// Access via [getAttachmentState] / [getOrCreateAttachmentState]; do not
  /// modify the map directly from UI code.
  final Map<String, AttachmentState> attachmentStates = {};

  /// Pending temp → real attachment GUID promotions registered by
  /// [MessagesService.notifyAttachmentSendComplete].  Used by
  /// [_syncAttachmentStates] to promote the correct state key when the real
  /// GUID arrives.  Entries are consumed (removed) after promotion.
  ///
  /// Keyed by **real** GUID with the temp GUID as the value: the lookup site
  /// only has the real GUID in hand (it's iterating the updated attachments),
  /// and needs the temp key the state is currently filed under.
  final Map<String, String> _pendingGuidPromotions = {};

  /// Observable fields for granular UI updates
  final RxnString guid;
  final RxnString text;
  final RxnString subject;
  final RxBool isFromMe;
  final Rxn<DateTime> dateCreated;
  final Rxn<DateTime> dateDelivered;
  final Rxn<DateTime> dateRead;
  final Rxn<DateTime> dateEdited;
  final RxInt error;
  final RxBool isDelivered;
  final RxBool hasAttachments;
  final RxBool hasReactions;
  final RxList<Message> associatedMessages; // reactions and edits
  final RxBool didNotifyRecipient;
  final RxBool wasDeliveredQuietly;
  final RxBool isBookmarked;
  final RxnString threadOriginatorGuid;
  final RxInt threadReplyCount;
  final RxnString associatedMessageGuid; // For reactions: parent message GUID
  final RxnString associatedMessageType; // For reactions: reaction type (loved, liked, etc)
  final RxnInt associatedMessagePart; // For reactions: which part of message

  /// Error message matching the [error] code. Null when no error.
  final RxnString errorMessage;

  // Derived/computed states for UI convenience
  final RxBool hasError;
  final RxBool isSending; // temp guid, no error
  final RxBool isSent; // not temp guid
  final RxBool isReaction; // has associatedMessageGuid

  /// Set to the message-part id that should play its bubble animation next frame.
  /// Consumers (BubbleEffects, TextBubble) wrap their animation trigger in Obx
  /// and react when this equals their own part id.  Reset to null after
  /// the animation has been kicked off so it can be retriggered later.
  final RxnInt playEffectPart = RxnInt(null);

  /// Whether the bubble effect for this message has already been auto-played
  /// once. Prevents the animation from firing again on subsequent renders.
  /// Manual replay via the replay button always works regardless of this flag.
  final RxBool hasEffectPlayed;

  /// Increment to trigger a re-download of all attachments in this message.
  /// [AttachmentHolder] registers `ever()` on this key to call _loadContent().
  final RxInt attachmentRefreshKey = 0.obs;

  /// Increment to trigger a re-fetch of embedded media in this message.
  /// [EmbeddedMedia] registers `ever()` on this key to call getContent().
  final RxInt embeddedMediaRefreshKey = 0.obs;

  /// Increment to trigger a refresh of web-loaded preview content (URL
  /// previews, Photos app previews, etc). [UrlPreview] and [PhotoSlideshow]
  /// register `ever()` on this key to clear their cached preview image and
  /// re-fetch. The "refresh preview" popup action clears `message.metadata`
  /// and bumps this key - each widget owns how it re-fetches its own content.
  final RxInt previewRefreshKey = 0.obs;

  // ========== Widget Controller Fields (merged from MessageWidgetController) ==========

  /// Whether to show previous edits for this message
  final RxBool showEdits = false.obs;

  /// Set by [MessagesService] when this outgoing message is the newest one
  /// whose [dateRead] is non-null.  Drives the "Read" indicator.
  final RxBool showReadIndicator = false.obs;

  /// Set by [MessagesService] when this outgoing message is the newest one
  /// with [dateDelivered] != null or [isDelivered] == true.  Drives the
  /// "Delivered" indicator.
  final RxBool showDeliveredIndicator = false.obs;

  /// Set when an audio message is kept; triggers delivered indicator
  final Rxn<DateTime> audioWasKept = Rxn<DateTime>(null);

  // If true, attachment widgets should be hidden. There is no "fake" attachment
  // to substitute, so a visibility flag is the only meaningful approach here.
  // Updated by MessagesService when hideAttachments or redactedMode settings change.
  final RxBool shouldHideAttachments =
      (SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideAttachments.value).obs;

  /// Reactive list of parsed message parts (text/attachments/edits/unsends).
  /// Populated by [buildMessageParts] in [onInit] and on content changes.
  final RxList<MessagePart> parts = <MessagePart>[].obs;

  /// Finds a part by its message-part id ([MessagePart.part]), not list index.
  MessagePart? partById(int partId) {
    final idx = parts.indexWhere((p) => p.part == partId);
    return idx >= 0 ? parts[idx] : null;
  }

  /// Whether [p] is the leading bubble of this message (covers raw part 0).
  ///
  /// Uses [MessagePart.coversPartId]; collapsed galleries keep a span in
  /// [MessagePart.attachmentPartIndices] and set [MessagePart.part] to the first id.
  bool isLeadingMessagePart(MessagePart p) => p.coversPartId(0);

  /// Whether [p] is the trailing bubble of this message (covers the last raw part id).
  ///
  /// Uses [parts] from [buildMessageParts] (not the collapsed UI list). Collapsed
  /// galleries keep a span in [MessagePart.attachmentPartIndices] and set
  /// [MessagePart.part] to the first id, so trailing is decided via [MessagePart.coversPartId].
  bool isTrailingMessagePart(MessagePart p) {
    if (parts.isEmpty) return true;
    return p.coversPartId(parts.last.part);
  }

  /// Reactive state for the handle that sent this message.
  /// Null for outgoing messages or when no handle is attached.
  /// Drives sender name and bubble color without boilerplate [ever()] calls.
  HandleState? sender;

  /// Resolves the display name for the sender of this message.
  ///
  /// - Outgoing: returns "You".
  /// - Incoming: returns the contact name from [sender], the handle's DB display
  ///   name (formatted address) as a fallback, or "Unknown" if no handle is
  ///   associated.
  ///
  /// Always reads [isFromMe.value] first, ensuring [Obx()] always registers at
  /// least one reactive dependency (prevents the GetX "improper use" warning
  /// even for outgoing group-event messages).
  String get senderDisplayName {
    if (isFromMe.value || sender == null) return 'You';
    return sender?.displayName.value ?? message.handleRelation.target?.displayName ?? 'Unknown';
  }

  /// Adjacent messages for layout context (set by MessageHolder in initState)
  Message? oldMessage;
  Message? newMessage;

  /// Parent conversation view controller (set by MessageHolder in initState)
  ConversationViewController? cvController;

  StreamSubscription? _sub;
  bool built = false;
  bool _partsCached = false;

  static const maxBubbleSizeFactor = 0.75;

  // ========== End Widget Controller Fields ==========

  MessageState(this.message)
      : guid = RxnString(message.guid),
        text = RxnString(message.text),
        subject = RxnString(message.subject),
        isFromMe = (message.isFromMe ?? true).obs,
        dateCreated = Rxn<DateTime>(message.dateCreated),
        dateDelivered = Rxn<DateTime>(message.dateDelivered),
        dateRead = Rxn<DateTime>(message.dateRead),
        dateEdited = Rxn<DateTime>(message.dateEdited),
        error = message.error.obs,
        isDelivered = message.isDelivered.obs,
        hasAttachments = message.hasAttachments.obs,
        hasReactions = message.hasReactions.obs,
        associatedMessages = message.associatedMessages.obs,
        didNotifyRecipient = message.didNotifyRecipient.obs,
        wasDeliveredQuietly = message.wasDeliveredQuietly.obs,
        isBookmarked = message.isBookmarked.obs,
        threadOriginatorGuid = RxnString(message.threadOriginatorGuid),
        threadReplyCount = 0.obs,
        associatedMessageGuid = RxnString(message.associatedMessageGuid),
        associatedMessageType = RxnString(message.associatedMessageType),
        associatedMessagePart = RxnInt(message.associatedMessagePart),
        errorMessage = RxnString(message.errorMessage),
        hasError = (message.error > 0).obs,
        isSending = (message.guid?.startsWith('temp') == true && message.error == 0).obs,
        isSent = (!(message.guid?.startsWith('temp') ?? false)).obs,
        isReaction = (message.associatedMessageGuid != null).obs,
        hasEffectPlayed = message.hasEffectPlayed.obs {
    // Create AttachmentState for every attachment already on the message.
    for (final attachment in message.dbAttachments) {
      if (attachment.guid != null) {
        attachmentStates[attachment.guid!] = AttachmentState(attachment);
      }
    }
    // Resolve sender HandleState for incoming messages.
    if (message.isFromMe != true && message.handleRelation.target != null && !kIsWeb) {
      sender = HandleSvc.getOrCreateHandleState(message.handleRelation.target!);
    }
  }

  @override
  void onInit() {
    super.onInit();
    buildMessageParts();
    // Apply initial redaction after parts are built.
    if (SettingsSvc.settings.redactedMode.value) redactFields();
    if (kIsWeb) {
      _sub = WebListeners.messageUpdate.listen((tuple) {
        final msg = tuple.message;
        final tempGuid = tuple.tempGuid;
        if (msg.guid == message.guid || tempGuid == message.guid) {
          updateMessage(msg);
        }
      });
    }
  }

  /// Signals that the bubble animation for [part] should play.
  /// [BubbleEffects] and [TextBubble] observe [playEffectPart] via ever() and
  /// fire their animation when its value matches their own message-part id.
  /// Resetting to null first ensures re-triggering the same part always fires.
  void triggerBubbleEffect(int part) {
    if (playEffectPart.value == part) playEffectPart.value = null;
    playEffectPart.value = part;
  }

  /// Marks this message's bubble effect as having been played once.
  /// Persists the flag to the database so it survives app restarts.
  /// Only called after an auto-triggered animation completes — manual
  /// replays do not call this.
  void markEffectPlayed() {
    if (hasEffectPlayed.value) return;
    hasEffectPlayed.value = true;
    message.setEffectPlayed();
  }

  /// Returns the [AttachmentState] for [attachmentGuid], or `null` if none
  /// has been registered yet.
  AttachmentState? getAttachmentState(String attachmentGuid) => attachmentStates[attachmentGuid];

  /// Records that the attachment state currently stored under [tempGuid]
  /// should be promoted to [realGuid] on the next [_syncAttachmentStates] call.
  /// Called by [MessagesService.notifyAttachmentSendComplete] so the promotion
  /// is deterministic even when the message has multiple attachments.
  void registerGuidPromotion(String tempGuid, String realGuid) {
    _pendingGuidPromotions[realGuid] = tempGuid;
  }

  /// Returns the [AttachmentState] for [attachmentGuid], creating one backed
  /// by [attachment] if it does not already exist.
  ///
  /// If [attachment] is omitted and the state does not exist, one is created
  /// by looking [attachmentGuid] up in [message.dbAttachments].  Throws if the
  /// attachment cannot be resolved.
  AttachmentState getOrCreateAttachmentState(String attachmentGuid, {Attachment? attachment}) {
    if (!attachmentStates.containsKey(attachmentGuid)) {
      final resolved = attachment ?? message.dbAttachments.firstWhereOrNull((a) => a.guid == attachmentGuid);
      if (resolved == null) {
        throw StateError(
          'Cannot create AttachmentState for $attachmentGuid: '
          'attachment not found in message ${message.guid}',
        );
      }
      attachmentStates[attachmentGuid] = AttachmentState(resolved);
    }
    return attachmentStates[attachmentGuid]!;
  }

  /// Synchronises [attachmentStates] with [updatedAttachments].
  ///
  /// * Existing states (same GUID) are updated via [AttachmentState.updateFromAttachment]
  ///   without resetting active transfer states.
  /// * New GUIDs cause new [AttachmentState] objects to be created.
  /// * Stale temp/error-prefixed states whose GUID is no longer present are
  ///   disposed and removed.
  void _syncAttachmentStates(List<Attachment?> updatedAttachments) {
    for (final attachment in updatedAttachments) {
      if (attachment?.guid == null) continue;
      final guid = attachment!.guid!;

      // Promote the state for this attachment if it has a pending temp -> real promotion registered.
      String? tempKey = _pendingGuidPromotions[guid];
      if (tempKey != null && attachmentStates.containsKey(tempKey)) {
        _pendingGuidPromotions.remove(guid);
        final promoted = attachmentStates.remove(tempKey)!;
        promoted.updateFromAttachment(attachment);
        promoted.updateGuidInternal(guid);
        attachmentStates[guid] = promoted;
      }

      if (attachmentStates.containsKey(guid)) {
        // Update metadata without touching the active transfer state.
        attachmentStates[guid]!.updateFromAttachment(attachment);
      } else {
        attachmentStates[guid] = AttachmentState(attachment);
      }
    }

    // Evict stale temp/error states that are no longer referenced.
    attachmentStates.removeWhere((key, state) {
      if (!(key.startsWith('temp') || key.startsWith('error'))) return false;
      final stillPresent = updatedAttachments.any((a) => a?.guid == key);
      if (!stillPresent) state.dispose();
      return !stillPresent;
    });
  }

  @override
  void onClose() {
    _sub?.cancel();
    for (final state in attachmentStates.values) {
      state.dispose();
    }
    attachmentStates.clear();
    super.onClose();
  }

  // ========== End AttachmentState Management ==========

  // ========== Internal State Update Methods ==========
  // These are called by MessagesService after DB operations complete
  // Do NOT call these directly - use MessagesService methods instead

  /// Update the message GUID (typically when temp -> real GUID)
  void updateGuidInternal(String? value) {
    if (guid.value != value) {
      guid.value = value;
      message.guid = value;

      // Update derived states
      isSending.value = (value?.startsWith('temp') ?? false) && !hasError.value;
      isSent.value = !(value?.startsWith('temp') ?? false);
    }
  }

  /// Update message text content
  void updateTextInternal(String? value) {
    if (text.value != value) {
      text.value = value;
      message.text = value;
    }
  }

  /// Update message subject
  void updateSubjectInternal(String? value) {
    if (subject.value != value) {
      subject.value = value;
      message.subject = value;
    }
  }

  /// Update creation timestamp
  void updateDateCreatedInternal(DateTime? value) {
    if (dateCreated.value != value) {
      dateCreated.value = value;
      message.dateCreated = value;
    }
  }

  /// Update delivery timestamp
  void updateDateDeliveredInternal(DateTime? value) {
    if (dateDelivered.value != value) {
      dateDelivered.value = value;
      message.dateDelivered = value;
      // Auto-update isDelivered flag
      isDelivered.value = value != null;
    }
  }

  /// Update read timestamp
  void updateDateReadInternal(DateTime? value) {
    if (dateRead.value != value) {
      dateRead.value = value;
      message.dateRead = value;
    }
  }

  /// Update edited timestamp
  void updateDateEditedInternal(DateTime? value) {
    if (dateEdited.value != value) {
      dateEdited.value = value;
      message.dateEdited = value;
    }
  }

  /// Update error code
  void updateErrorInternal(int value) {
    if (error.value != value) {
      error.value = value;
      message.error = value;
      // Auto-update hasError flag
      hasError.value = value > 0;
      // A temp GUID with a non-zero error is no longer "sending"
      isSending.value = (guid.value?.startsWith('temp') ?? false) && value == 0;
    }
  }

  /// Update the client-side error message
  void updateErrorMessageInternal(String? value) {
    if (errorMessage.value != value) {
      errorMessage.value = value;
      message.errorMessage = value;
    }
  }

  /// Update isDelivered flag directly (for cases without timestamp)
  void updateIsDeliveredInternal(bool value) {
    if (isDelivered.value != value) {
      isDelivered.value = value;
      message.isDelivered = value;
    }
  }

  /// Replace all associated messages (reactions/edits)
  void updateAssociatedMessagesInternal(List<Message> value) {
    associatedMessages.value = value;
    message.associatedMessages = value;
    hasReactions.value = value.isNotEmpty;
  }

  /// Add or update a single associated message (reaction/edit)
  /// Handles both new additions and updates to existing reactions
  /// Optional tempGuid parameter to replace temp reactions with real ones
  void addAssociatedMessageInternal(Message reaction, {String? tempGuid}) {
    // Try to find existing reaction by ID or GUID
    int index = associatedMessages.indexWhere((e) =>
        (e.id == reaction.id && e.id != null) ||
        (e.guid == reaction.guid && !reaction.guid!.startsWith('temp')) ||
        (tempGuid != null && e.guid == tempGuid));

    if (index >= 0) {
      // Update existing reaction
      associatedMessages[index] = reaction;
    } else {
      // Check if this replaces a temp reaction
      final tempIndex = associatedMessages.indexWhere((e) =>
          (e.guid?.startsWith('temp') == true || e.guid?.startsWith('error') == true) &&
          e.associatedMessageType == reaction.associatedMessageType &&
          (e.associatedMessagePart ?? 0) == (reaction.associatedMessagePart ?? 0));

      if (tempIndex >= 0) {
        // Replace temp reaction
        associatedMessages[tempIndex] = reaction;
      } else {
        // Add new reaction
        associatedMessages.add(reaction);
      }
    }

    // Update underlying message and hasReactions flag
    message.associatedMessages = associatedMessages.toList();
    hasReactions.value = associatedMessages.isNotEmpty;
  }

  /// Alias for addAssociatedMessageInternal to match controller naming
  void updateAssociatedMessageInternal(Message reaction, {String? tempGuid}) {
    addAssociatedMessageInternal(reaction, tempGuid: tempGuid);
  }

  /// Remove an associated message (reaction/edit)
  void removeAssociatedMessageInternal(Message reaction) {
    associatedMessages.removeWhere((e) => e.id == reaction.id);
    message.associatedMessages = associatedMessages.toList();
    hasReactions.value = associatedMessages.isNotEmpty;
  }

  /// Update recipient notification flag
  void updateDidNotifyRecipientInternal(bool value) {
    if (didNotifyRecipient.value != value) {
      didNotifyRecipient.value = value;
      message.didNotifyRecipient = value;
    }
  }

  /// Update quiet delivery flag
  void updateWasDeliveredQuietlyInternal(bool value) {
    if (wasDeliveredQuietly.value != value) {
      wasDeliveredQuietly.value = value;
      message.wasDeliveredQuietly = value;
    }
  }

  /// Update bookmark status
  void updateIsBookmarkedInternal(bool value) {
    if (isBookmarked.value != value) {
      isBookmarked.value = value;
      message.isBookmarked = value;
    }
  }

  /// Called by [MessagesService] — do not invoke from UI code.
  void updateShowReadIndicatorInternal(bool value) {
    if (showReadIndicator.value != value) showReadIndicator.value = value;
  }

  /// Called by [MessagesService] — do not invoke from UI code.
  void updateShowDeliveredIndicatorInternal(bool value) {
    if (showDeliveredIndicator.value != value) showDeliveredIndicator.value = value;
  }

  /// Update thread reply count (computed from thread messages)
  void updateThreadReplyCountInternal(int count) {
    if (threadReplyCount.value != count) {
      threadReplyCount.value = count;
    }
  }

  /// Update thread originator GUID
  void updateThreadOriginatorGuidInternal(String? value) {
    if (threadOriginatorGuid.value != value) {
      threadOriginatorGuid.value = value;
      message.threadOriginatorGuid = value;
    }
  }

  /// Update hasAttachments flag
  void updateHasAttachmentsInternal(bool value) {
    if (hasAttachments.value != value) {
      hasAttachments.value = value;
      message.hasAttachments = value;
    }
  }

  /// Update hasReactions flag directly (in addition to auto-update from associatedMessages)
  void updateHasReactionsInternal(bool value) {
    if (hasReactions.value != value) {
      hasReactions.value = value;
      message.hasReactions = value;
    }
  }

  /// Update associated message properties (for reactions)
  void updateAssociatedMessageInfoInternal({
    String? associatedMessageGuid,
    String? associatedMessageType,
    int? associatedMessagePart,
  }) {
    if (associatedMessageGuid != null && this.associatedMessageGuid.value != associatedMessageGuid) {
      this.associatedMessageGuid.value = associatedMessageGuid;
      message.associatedMessageGuid = associatedMessageGuid;
      isReaction.value = true;
    }

    if (associatedMessageType != null && this.associatedMessageType.value != associatedMessageType) {
      this.associatedMessageType.value = associatedMessageType;
      message.associatedMessageType = associatedMessageType;
    }

    if (associatedMessagePart != null && this.associatedMessagePart.value != associatedMessagePart) {
      this.associatedMessagePart.value = associatedMessagePart;
      message.associatedMessagePart = associatedMessagePart;
    }
  }

  /// Update state from database message object
  /// Used when message is refreshed from DB or merged with updates
  void updateFromMessage(Message updatedMessage) {
    // Update all observable fields
    updateGuidInternal(updatedMessage.guid);
    updateTextInternal(updatedMessage.text);
    updateSubjectInternal(updatedMessage.subject);
    updateDateDeliveredInternal(updatedMessage.dateDelivered);
    updateDateReadInternal(updatedMessage.dateRead);
    updateDateEditedInternal(updatedMessage.dateEdited);
    updateErrorInternal(updatedMessage.error);
    updateErrorMessageInternal(updatedMessage.errorMessage);
    updateDidNotifyRecipientInternal(updatedMessage.didNotifyRecipient);
    updateWasDeliveredQuietlyInternal(updatedMessage.wasDeliveredQuietly);
    updateThreadOriginatorGuidInternal(updatedMessage.threadOriginatorGuid);
    updateHasAttachmentsInternal(updatedMessage.hasAttachments);
    updateHasReactionsInternal(updatedMessage.hasReactions);

    // Update isFromMe if changed
    if (isFromMe.value != updatedMessage.isFromMe) {
      isFromMe.value = updatedMessage.isFromMe ?? true;
      message.isFromMe = updatedMessage.isFromMe;
    }

    // Update dateCreated if changed
    if (dateCreated.value != updatedMessage.dateCreated) {
      dateCreated.value = updatedMessage.dateCreated;
      message.dateCreated = updatedMessage.dateCreated;
    }

    // Update associated message info if this is a reaction
    if (updatedMessage.associatedMessageGuid != null) {
      updateAssociatedMessageInfoInternal(
        associatedMessageGuid: updatedMessage.associatedMessageGuid,
        associatedMessageType: updatedMessage.associatedMessageType,
        associatedMessagePart: updatedMessage.associatedMessagePart,
      );
    }

    // Merge other non-observable properties
    message.handleId = updatedMessage.handleId;
    message.otherHandle = updatedMessage.otherHandle;
    message.country = updatedMessage.country;
    message.hasDdResults = updatedMessage.hasDdResults;
    message.datePlayed = updatedMessage.datePlayed;
    message.itemType = updatedMessage.itemType;
    message.groupTitle = updatedMessage.groupTitle;
    message.groupActionType = updatedMessage.groupActionType;
    message.balloonBundleId = updatedMessage.balloonBundleId;
    message.expressiveSendStyleId = updatedMessage.expressiveSendStyleId;
    message.dateDeleted = updatedMessage.dateDeleted;
    message.metadata = updatedMessage.metadata;
    message.threadOriginatorPart = updatedMessage.threadOriginatorPart;
    message.bigEmoji = updatedMessage.bigEmoji;
    message.attributedBody = updatedMessage.attributedBody;
    message.messageSummaryInfo = updatedMessage.messageSummaryInfo;
    message.payloadData = updatedMessage.payloadData;
    message.hasApplePayloadData = updatedMessage.hasApplePayloadData;
    message.isBookmarked = updatedMessage.isBookmarked;

    // Keep AttachmentState as the UI source of truth, synchronized from dbAttachments.
    _syncAttachmentStates(updatedMessage.dbAttachments);
  }

  /// Convenience getter: Is this message in an error state?
  bool get isError => hasError.value;

  /// Convenience getter: Is this message currently being sent?
  bool get isCurrentlySending => isSending.value;

  /// Convenience getter: Has this message been sent successfully?
  bool get isSuccessfullySent => isSent.value && !hasError.value;

  /// Convenience getter: Is this a reaction message?
  bool get isReactionMessage => isReaction.value;

  /// Convenience getter: Count of reactions on this message
  int get reactionCount => associatedMessages.length;

  // ========== Unsent / Retracted Getters ==========
  // These read from [parts] (RxList) and [dateEdited] (Rxn) so they
  // automatically trigger Obx rebuilds when either field changes.

  /// Indices of parts that have been unsent, derived from the live [parts] list.
  List<int> get retractedParts => parts.where((p) => p.isUnsent).map((p) => p.part).toList();

  /// True when at least one part has been retracted.
  bool get hasUnsentParts => dateEdited.value != null && retractedParts.isNotEmpty;

  /// True when every part has been retracted (entire message unsent).
  bool get isFullyUnsent => hasUnsentParts && parts.isNotEmpty && parts.every((p) => p.isUnsent);

  /// True when some — but not all — parts have been retracted.
  bool get isPartiallyUnsent => hasUnsentParts && parts.any((p) => p.isUnsent) && parts.any((p) => !p.isUnsent);

  // ========== End Unsent / Retracted Getters ==========

  // ========== Redaction Methods ==========
  // These are called when redacted mode settings change

  /// Redact message content by setting [MessagePart.shouldRedact] on every part,
  /// which causes [MessagePart.displayText] / [displaySubject] to return their
  /// faker-generated fake text.  The real text in [message] is never mutated
  /// so it can be restored cleanly by [unredactMessageContent].
  void redactMessageContent() {
    if (!SettingsSvc.settings.redactedMode.value) return;
    if (!SettingsSvc.settings.hideMessageContent.value) return;

    for (final part in parts) {
      part.shouldRedact = true;
    }
    if (parts.isNotEmpty) parts.refresh();
  }

  /// Restore message content by clearing [MessagePart.shouldRedact] on every part.
  void unredactMessageContent() {
    for (final part in parts) {
      part.shouldRedact = false;
    }
    if (parts.isNotEmpty) parts.refresh();
  }

  /// Apply all redactions based on current settings (used on initialization)
  void redactFields() {
    if (!SettingsSvc.settings.redactedMode.value) return;

    redactMessageContent();
    updateShouldHideAttachmentsInternal(SettingsSvc.settings.hideAttachments.value);
  }

  /// Remove all redactions (used when redacted mode is disabled)
  void unredactFields() {
    unredactMessageContent();
    updateShouldHideAttachmentsInternal(false);
  }

  void updateShouldHideAttachmentsInternal(bool value) {
    if (shouldHideAttachments.value != value) shouldHideAttachments.value = value;
  }

  // ========== Part Building (merged from MessageWidgetController) ==========

  void buildMessageParts({bool force = false}) {
    if (_partsCached && !force) return;
    final newParts = <MessagePart>[];

    if (message.attributedBody.firstOrNull?.runs.isNotEmpty ?? false) {
      newParts.addAll(attributedBodyToMessagePart(message.attributedBody.first));
    }
    if (message.messageSummaryInfo.firstOrNull?.editedParts.isNotEmpty ?? false) {
      for (int part in message.messageSummaryInfo.first.editedParts) {
        final edits = message.messageSummaryInfo.first.editedContent[part.toString()] ?? [];
        final existingPart = newParts.firstWhereOrNull((element) => element.part == part);
        if (existingPart != null) {
          existingPart.edits.addAll(edits
              .where((e) => e.text?.values.isNotEmpty ?? false)
              .map((e) => attributedBodyToMessagePart(e.text!.values.first).firstOrNull)
              .where((e) => e != null)
              .map((e) => e!)
              .toList());
          if (existingPart.edits.isNotEmpty) {
            existingPart.edits.removeLast();
          }
        }
      }
    }
    if (message.messageSummaryInfo.firstOrNull?.retractedParts.isNotEmpty ?? false) {
      for (int part in message.messageSummaryInfo.first.retractedParts) {
        final existing = newParts.indexWhere((e) => e.part == part);
        if (existing >= 0) {
          newParts.removeAt(existing);
        }
        newParts.add(MessagePart(
          part: part,
          isUnsent: true,
        ));
      }
    }
    if (newParts.isEmpty) {
      if (!message.hasApplePayloadData &&
          !message.isLegacyUrlPreview &&
          !message.isInteractive &&
          !message.isGroupEvent) {
        newParts.addAll(message.dbAttachments.mapIndexed((index, e) => MessagePart(
              attachments: [e],
              part: index,
            )));
      } else if (message.isInteractive) {
        newParts.add(MessagePart(
          part: 0,
        ));
      }

      if (message.fullText.isNotEmpty || message.isGroupEvent) {
        newParts.add(MessagePart(
          subject: message.subject,
          text: message.text,
          part: newParts.length,
        ));
      }
    }
    newParts.sort((a, b) => a.part.compareTo(b.part));
    // Stamp each freshly-built part with the current redaction state so widgets
    // read MessagePart.displayText / displaySubject without checking settings.
    final redact = SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideMessageContent.value;
    for (final part in newParts) {
      part.shouldRedact = redact;
    }
    parts.assignAll(newParts);
    _partsCached = true;
  }

  List<MessagePart> attributedBodyToMessagePart(AttributedBody body) {
    final mainString = body.string;
    final list = <MessagePart>[];
    body.runs.sort((a, b) => a.range.first.compareTo(b.range.first));
    body.runs.forEachIndexed((i, e) async {
      if (e.attributes?.messagePart == null) return;
      final existingPart = list.firstWhereOrNull((element) => element.part == e.attributes!.messagePart!);
      if (existingPart != null) {
        final newText = mainString.substring(e.range.first, e.range.first + e.range.last);
        final currentLength = existingPart.text?.length ?? 0;
        existingPart.text = (existingPart.text ?? "") + newText;
        if (e.hasMention) {
          existingPart.mentions.add(Mention(
            mentionedAddress: e.attributes?.mention,
            range: [currentLength, currentLength + e.range.last],
          ));
          existingPart.mentions.sort((a, b) => a.range.first.compareTo(b.range.first));
        }
      } else {
        Attachment? foundAttachment;
        if (e.isAttachment && (cvController?.chat != null || ChatsSvc.activeChat != null)) {
          final attachmentGuid = e.attributes!.attachmentGuid!;
          foundAttachment = message.dbAttachments.firstWhereOrNull((a) => a.guid == attachmentGuid);
          if (foundAttachment == null) {
            foundAttachment = maybeFindMessagesSvc(cvController?.chat.guid ?? ChatsSvc.activeChat!.chat.guid)
                ?.struct
                .getAttachment(attachmentGuid);
            foundAttachment ??= await Attachment.findOneAsync(attachmentGuid);
          }
        }

        list.add(MessagePart(
          subject: i == 0 ? message.subject : null,
          text: e.isAttachment ? null : mainString.substring(e.range.first, e.range.first + e.range.last),
          attachments: foundAttachment != null ? [foundAttachment] : [],
          mentions: !e.hasMention
              ? []
              : [
                  Mention(
                    mentionedAddress: e.attributes?.mention,
                    range: [0, e.range.last],
                  )
                ],
          part: e.attributes!.messagePart!,
        ));
      }
    });
    return list;
  }

  /// Called by [MessagesService] during a temp → real GUID swap AFTER the
  /// service has already updated this [MessageState] and the state map.
  /// Merges the updated message, rebuilds parts — without re-entering
  /// [MessagesService.updateMessage].
  void notifyGuidSwap(Message updated) {
    message = Message.merge(updated, message);
    _partsCached = false;
    buildMessageParts(force: true);
  }

  /// Called by the web listener to handle incoming message updates.
  /// Merges the new data and delegates to [MessagesService.updateMessage]
  /// for struct/state coordination.
  void updateMessage(Message newItem) {
    final chat = message.chat.target?.guid ?? cvController?.chat.guid ?? ChatsSvc.activeChat!.chat.guid;
    final oldGuid = message.guid;

    if (newItem.guid != oldGuid && oldGuid!.contains("temp")) {
      message = Message.merge(newItem, message);
      MessagesSvc(chat).updateMessage(message, oldGuid: oldGuid);
      _partsCached = false;
      buildMessageParts(force: true);
      return;
    }

    final hasDeliveryChanged = newItem.dateDelivered != message.dateDelivered;
    final hasReadChanged = newItem.dateRead != message.dateRead;
    final hasEdited = newItem.dateEdited != message.dateEdited;

    if (hasDeliveryChanged || hasReadChanged) {
      message = Message.merge(newItem, message);
      MessagesSvc(chat).updateMessage(message);
      if (hasEdited) {
        _partsCached = false;
        buildMessageParts(force: true);
      }
      return;
    }

    if (hasEdited) {
      message = Message.merge(newItem, message);
      _partsCached = false;
      buildMessageParts(force: true);
      MessagesSvc(chat).updateMessage(message);
      return;
    }

    message = Message.merge(newItem, message);
    MessagesSvc(chat).updateMessage(message);
  }

  // ========== End Part Building ==========
}
