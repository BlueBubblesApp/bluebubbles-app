import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/chat_event/chat_event.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder/message_holder_indicators.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder/message_holder_reactions.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder/message_holder_timestamps.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder/message_holder_wrappers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder/message_reactions.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder/reply_bubble_section.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/bubble_effects.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/message_edit_field.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/message_part_content.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/message_properties.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/message_sender.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/select_checkbox.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/slide_to_reply.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/swipe_to_reply_wrapper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_line_painter.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/text_bubble.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/message_timestamp.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/timestamp_separator.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MessageHolder extends StatefulWidget {
  MessageHolder({
    super.key,
    required this.cvController,
    this.oldMessage,
    this.newMessage,
    required this.message,
    this.isReplyThread = false,
    this.replyPart,
  }) : ms = MessagesSvc(cvController.chat.guid).getOrCreateState(message);

  final MessageState ms;
  final Message message;
  final Message? oldMessage;
  final Message? newMessage;
  final ConversationViewController cvController;
  final bool isReplyThread;
  final int? replyPart;

  @override
  State<StatefulWidget> createState() => _MessageHolderState();
}

class _MessageHolderState extends State<MessageHolder> with ThemeHelpers {
  MessageState get controller => widget.ms;

  Message get message => controller.message;

  Message? get olderMessage => controller.oldMessage;

  Message? get newerMessage => controller.newMessage;

  // Computed reactive replyTo getter
  Message? get replyTo => message.threadOriginatorGuid == null
      ? null
      : SettingsSvc.settings.repliesToPrevious.value
          ? (service.struct
                  .getPreviousReply(message.threadOriginatorGuid!, message.normalizedThreadPart, message.guid!) ??
              service.struct.getThreadOriginator(message.threadOriginatorGuid!))
          : service.struct.getThreadOriginator(message.threadOriginatorGuid!);

  Chat get chat => widget.cvController.chat;

  MessagesService get service => MessagesSvc(widget.cvController.chat.guid);

  // Computed reactive properties
  bool get showSender =>
      !message.isGroupEvent &&
      (!message.sameSender(olderMessage) ||
          (olderMessage?.isGroupEvent ?? false) ||
          (olderMessage == null || !message.dateCreated!.isWithin(olderMessage!.dateCreated!, minutes: 30)));

  bool get canSwipeToReply =>
      SettingsSvc.settings.enablePrivateAPI.value &&
      SettingsSvc.serverDetails.isMinBigSur &&
      chat.isIMessage &&
      !widget.isReplyThread &&
      !controller.isSending.value &&
      !controller.hasError.value;

  bool get showAvatar => chat.isGroup;

  bool isEditing(int part) =>
      message.isFromMe! &&
      widget.cvController.editing.firstWhereOrNull((e2) => e2.message.guid == message.guid! && e2.part.part == part) !=
          null;

  List<RxDouble> replyOffsets = [];
  List<GlobalKey> keys = [];
  final RxBool tapped = false.obs;
  final Map<int, ValueNotifier<int>> _galleryIndices = {};

  @override
  void dispose() {
    for (final notifier in _galleryIndices.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.isReplyThread) {
      replyOffsets = List.generate(widget.replyPart != null ? 1 : controller.parts.length, (_) => 0.0.obs);
      keys = List.generate(widget.replyPart != null ? 1 : controller.parts.length, (_) => GlobalKey());
    } else {
      controller.cvController = widget.cvController;
      controller.oldMessage = widget.oldMessage;
      controller.newMessage = widget.newMessage;
      replyOffsets = List.generate(controller.parts.length, (_) => 0.0.obs);
      keys = List.generate(controller.parts.length, (_) => GlobalKey());
    }
  }

  void completeEdit(String newEdit, int part) async {
    widget.cvController.editing.removeWhere((e2) => e2.message.guid == message.guid! && e2.part.part == part);
    if (newEdit.isNotEmpty && newEdit != controller.parts.firstWhere((element) => element.part == part).text) {
      await service.editMessage(message, part, newEdit);
    }
    widget.cvController.lastFocusedNode.requestFocus();
  }

  List<MessagePart> _collapseImageGalleryParts(List<MessagePart> parts) {
    if (!iOS) return parts;
    final collapsed = <MessagePart>[];
    int i = 0;
    while (i < parts.length) {
      final current = parts[i];
      if (!current.isMediaOnlyPart) {
        collapsed.add(current);
        i++;
        continue;
      }

      final groupedAttachments = <Attachment>[...current.attachments];
      final groupedPartIndices = <int>[...List.filled(current.attachments.length, current.part)];
      int j = i + 1;
      while (j < parts.length) {
        final next = parts[j];
        if (!next.isMediaOnlyPart) break;
        groupedAttachments.addAll(next.attachments);
        groupedPartIndices.addAll(List.filled(next.attachments.length, next.part));
        j++;
      }

      if (groupedAttachments.length > 1) {
        collapsed.add(MessagePart(
          attachments: groupedAttachments,
          part: current.part,
          shouldRedact: current.shouldRedact,
          mentions: const [],
          edits: const [],
          isUnsent: current.isUnsent,
          attachmentPartIndices: groupedPartIndices,
        ));
      } else {
        collapsed.add(current);
      }
      i = j;
    }
    return collapsed;
  }

  @override
  Widget build(BuildContext context) {
    controller.built = true;

    // Cache settings values to avoid repeated observable reads
    final alwaysShowAvatars = SettingsSvc.settings.alwaysShowAvatars.value;
    final avatarScale = SettingsSvc.settings.avatarScale.value;

    Iterable<Message> reactionsForPart(int part, List<Message> reactions) {
      return reactions.where((s) => (s.associatedMessagePart ?? 0) == part);
    }

    /// Layout tree
    /// - Timestamp
    /// - Stack (see code comment)
    ///    - avatar | message row
    ///                - spacing (for avatar) | message column | message timestamp
    ///                                          - message part column
    ///                                             - message sender
    ///                                             - reaction spacing box
    ///                                             - previous edits
    ///                                             - message content row
    ///                                                - text / attachment / chat event / interactive | slide to reply
    ///                                                   |-> stack: stickers & reactions
    ///                                             - message properties
    ///                                          - delivered indicator
    // Item Type 5 indicates a kept audio message, we don't need to show this
    if (message.itemType == 5 && message.subject != null) {
      return const SizedBox.shrink();
    }
    final messageState = controller;
    return MessageStateScope(
      messageState: messageState,
      child: Obx(() {
        // Ensure this Obx always has direct reactive dependencies from MessageState.
        // Some render paths can avoid touching other Rx fields.
        // ignore: unused_local_variable
        final _rxGuard = (controller.isSending.value, controller.hasError.value, controller.parts.length);

        // Read controller.parts reactively so Obx rebuilds when parts change
        final rawMessageParts = widget.isReplyThread && widget.replyPart != null
            ? [controller.parts[widget.replyPart!]]
            : controller.parts.toList();
        final messageParts = _collapseImageGalleryParts(rawMessageParts);

        // Grow per-part arrays so replyOffsets[index] and keys[index] are
        // always safe to access, even when parts are added after initState.
        while (replyOffsets.length < messageParts.length) {
          replyOffsets.add(0.0.obs);
          keys.add(GlobalKey());
        }

        // Use MessageState observables for proper reactivity
        final isFromMe = controller.message.isFromMe!;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 100),
          padding: EdgeInsets.only(
            top: olderMessage != null && !message.sameSender(olderMessage!) ? 5.0 : 0,
            bottom: newerMessage != null && !message.sameSender(newerMessage!) ? 5.0 : 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // large timestamp between messages
              TimestampSeparator(olderMessage: olderMessage),
              // use stack so avatar can be placed at bottom
              Row(
                children: [
                  if (!isFromMe && !message.isGroupEvent) SelectCheckbox(controller: widget.cvController),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        // message column
                        ...messageParts.mapIndexed((index, e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  // add previous edits if needed
                                  if (e.isEdited)
                                    EditHistoryObserver(
                                      part: e,
                                      newerMessage: newerMessage,
                                      showAvatar: showAvatar,
                                      alwaysShowAvatars: alwaysShowAvatars,
                                      avatarScale: avatarScale,
                                    ),
                                  if (iOS &&
                                      index == 0 &&
                                      !widget.isReplyThread &&
                                      olderMessage != null &&
                                      message.threadOriginatorGuid != null &&
                                      message.showUpperMessage(olderMessage!) &&
                                      replyTo != null &&
                                      service.getMessageStateIfExists(replyTo!.guid!) != null)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          left: (showAvatar || alwaysShowAvatars) && replyTo!.isFromMe! ? 35 : 0),
                                      child: DecoratedBox(
                                        decoration: replyTo!.isFromMe == message.isFromMe
                                            ? ReplyLineDecoration(
                                                isFromMe: message.isFromMe!,
                                                color: context.theme.colorScheme.surfaceContainerHighest,
                                                connectUpper: false,
                                                connectLower: true,
                                                context: context,
                                              )
                                            : const BoxDecoration(),
                                        child: ReplyBubbleSection(
                                          replyTo: replyTo!,
                                          cvController: widget.cvController,
                                          showAvatar: showAvatar,
                                          alwaysShowAvatars: alwaysShowAvatars,
                                          avatarScale: avatarScale,
                                          isIOS: true,
                                          isFirstPart: true,
                                        ),
                                      ),
                                    ),
                                  // show sender, if needed
                                  if (chat.isGroup &&
                                      !message.isFromMe! &&
                                      showSender &&
                                      e.part == (messageParts.firstWhereOrNull((e) => !e.isUnsent)?.part))
                                    Padding(
                                      padding: showAvatar || alwaysShowAvatars
                                          ? EdgeInsets.only(left: 35.0 * avatarScale)
                                          : EdgeInsets.zero,
                                      child: iOS && !widget.isReplyThread && message.threadOriginatorGuid != null
                                          ? SizedBox(
                                              width: double.infinity,
                                              child: CustomPaint(
                                                painter: _ReplyLinePainter(
                                                  color: context.theme.colorScheme.surfaceContainerHighest,
                                                  isFromMe: message.isFromMe!,
                                                ),
                                                child: MessageSender(olderMessage: olderMessage),
                                              ),
                                            )
                                          : MessageSender(olderMessage: olderMessage),
                                    ),
                                  // add a box to account for height of reactions
                                  iOS &&
                                          !widget.isReplyThread &&
                                          message.threadOriginatorGuid != null &&
                                          replyTo != null &&
                                          replyTo!.isFromMe!
                                      ? SizedBox(
                                          width: double.infinity,
                                          child: CustomPaint(
                                            painter: _ReplyLinePainter(
                                              color: context.theme.colorScheme.surfaceContainerHighest,
                                              isFromMe: message.isFromMe!,
                                            ),
                                            child: ReactionSpacing(
                                              messageParts: messageParts,
                                              part: e,
                                              reactionsForPart: reactionsForPart,
                                              minHeightWhenNoReactions: message.isFromMe! ? 8 : 0,
                                            ),
                                          ),
                                        )
                                      : ReactionSpacing(
                                          messageParts: messageParts,
                                          part: e,
                                          reactionsForPart: reactionsForPart,
                                          minHeightWhenNoReactions: iOS &&
                                                  !widget.isReplyThread &&
                                                  message.threadOriginatorGuid != null &&
                                                  message.isFromMe!
                                              ? 8
                                              : 0,
                                        ),
                                  if (!iOS &&
                                      index == 0 &&
                                      !widget.isReplyThread &&
                                      olderMessage != null &&
                                      message.threadOriginatorGuid != null &&
                                      replyTo != null &&
                                      service.getMessageStateIfExists(replyTo!.guid!) != null)
                                    ReplyBubbleSection(
                                      replyTo: replyTo!,
                                      cvController: widget.cvController,
                                      showAvatar: showAvatar,
                                      alwaysShowAvatars: alwaysShowAvatars,
                                      avatarScale: avatarScale,
                                      isIOS: false,
                                      isFirstPart: true,
                                    ),
                                  Stack(
                                    alignment: Alignment.bottomLeft,
                                    children: [
                                      // avatar, if needed
                                      if (message.showTail(newerMessage) &&
                                          e.part == controller.parts.length - 1 &&
                                          (showAvatar || SettingsSvc.settings.alwaysShowAvatars.value) &&
                                          !message.isFromMe! &&
                                          !message.isGroupEvent)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 5.0),
                                          child: ContactAvatarWidget(
                                            handle: message.handleRelation.target,
                                            size: iOS ? 30 : 35,
                                            fontSize: context.theme.textTheme.bodyLarge!.fontSize!,
                                            borderThickness: 0.1,
                                          ),
                                        ),
                                      Padding(
                                        padding:
                                            (showAvatar || alwaysShowAvatars) && !(message.isGroupEvent || e.isUnsent)
                                                ? EdgeInsets.only(left: 35.0 * avatarScale)
                                                : EdgeInsets.zero,
                                        child: DecoratedBox(
                                          decoration: iOS &&
                                                  !widget.isReplyThread &&
                                                  ((index == 0 &&
                                                          message.threadOriginatorGuid != null &&
                                                          olderMessage != null) ||
                                                      (index == messageParts.length - 1 &&
                                                          service.struct.threads(message.guid!, index).isNotEmpty &&
                                                          newerMessage != null))
                                              ? ReplyLineDecoration(
                                                  isFromMe: message.isFromMe!,
                                                  color: context.theme.colorScheme.surfaceContainerHighest,
                                                  connectUpper: message.connectToUpper(),
                                                  connectLower:
                                                      newerMessage != null && message.connectToLower(newerMessage!),
                                                  context: context,
                                                )
                                              : const BoxDecoration(),
                                          child: SelectModeWrapper(
                                            cvController: widget.cvController,
                                            tapped: tapped,
                                            child: Align(
                                              alignment:
                                                  message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // show group event
                                                  if (message.isGroupEvent || e.isUnsent)
                                                    ChatEvent(
                                                      part: e,
                                                    ),
                                                  if (samsung)
                                                    SamsungTimestampObserver(
                                                      messageParts: messageParts,
                                                      part: e,
                                                      cvController: widget.cvController,
                                                      reactionsForPart: reactionsForPart,
                                                    ),
                                                  // otherwise show content
                                                  if (!message.isGroupEvent && !e.isUnsent)
                                                    Column(
                                                      crossAxisAlignment:
                                                          isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                      children: [
                                                        // interactive messages may have subjects, so render them here
                                                        // also render the subject for attachments that may have not rendered already
                                                        if ((message.hasApplePayloadData ||
                                                                message.isLegacyUrlPreview ||
                                                                message.isInteractive ||
                                                                (e.part == 0 &&
                                                                    isNullOrEmpty(e.text) &&
                                                                    e.attachments.isNotEmpty)) &&
                                                            !isNullOrEmpty(message.subject))
                                                          Padding(
                                                            padding: const EdgeInsets.only(bottom: 2.0),
                                                            child: ClipPath(
                                                              clipper: TailClipper(
                                                                isFromMe: isFromMe,
                                                                showTail: false,
                                                                connectLower: iOS
                                                                    ? false
                                                                    : (e.part != 0 &&
                                                                            e.part != controller.parts.length - 1) ||
                                                                        (e.part == 0 && controller.parts.length > 1),
                                                                connectUpper: iOS ? false : e.part != 0,
                                                              ),
                                                              child: TextBubble(
                                                                message: MessagePart(
                                                                  subject: e.subject,
                                                                  part: e.part,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        Stack(
                                                          alignment:
                                                              isFromMe ? Alignment.centerRight : Alignment.centerLeft,
                                                          fit: StackFit.loose,
                                                          clipBehavior: Clip.none,
                                                          children: [
                                                            // Inner Stack: bubble + reactions, sized by the bubble alone
                                                            // so reactions are always anchored to the bubble edge
                                                            Stack(
                                                              alignment: isFromMe
                                                                  ? Alignment.centerRight
                                                                  : Alignment.centerLeft,
                                                              fit: StackFit.loose,
                                                              clipBehavior: Clip.none,
                                                              children: [
                                                                // actual message content
                                                                BubbleEffects(
                                                                  part: index,
                                                                  globalKey: keys.length > index ? keys[index] : null,
                                                                  showTail: message.showTail(newerMessage) &&
                                                                      e.part == controller.parts.length - 1,
                                                                  child: MessagePopupHolder(
                                                                    key: keys.length > index ? keys[index] : null,
                                                                    controller: controller,
                                                                    cvController: widget.cvController,
                                                                    part: e,
                                                                    isEditing: isEditing(e.part),
                                                                    galleryCurrentIndex: e.isMediaGallery
                                                                        ? _galleryIndices.putIfAbsent(
                                                                            e.part, () => ValueNotifier(0))
                                                                        : null,
                                                                    child: SwipeToReplyWrapper(
                                                                      enabled: canSwipeToReply && !isEditing(e.part),
                                                                      partIndex: index,
                                                                      replyOffset: replyOffsets[index],
                                                                      cvController: widget.cvController,
                                                                      child: Builder(
                                                                        builder: (_) {
                                                                          final isGallery = iOS && e.isMediaGallery;
                                                                          final inner = Stack(
                                                                            alignment: Alignment.centerRight,
                                                                            children: [
                                                                              MessagePartContent(
                                                                                messagePart: e,
                                                                                galleryCurrentIndexNotifier: e
                                                                                        .isMediaGallery
                                                                                    ? _galleryIndices.putIfAbsent(
                                                                                        e.part, () => ValueNotifier(0))
                                                                                    : null,
                                                                              ),
                                                                              if (message.isFromMe!)
                                                                                Obx(() {
                                                                                  final editStuff = widget
                                                                                      .cvController.editing
                                                                                      .firstWhereOrNull((e2) =>
                                                                                          e2.message.guid ==
                                                                                              message.guid! &&
                                                                                          e2.part.part == e.part);
                                                                                  return AnimatedSize(
                                                                                      duration: const Duration(
                                                                                          milliseconds: 250),
                                                                                      alignment: Alignment.centerRight,
                                                                                      curve: Curves.easeOutBack,
                                                                                      child: editStuff == null
                                                                                          ? const SizedBox.shrink()
                                                                                          : MessageEditField(
                                                                                              part: e.part,
                                                                                              editController:
                                                                                                  editStuff.controller,
                                                                                              cvController:
                                                                                                  widget.cvController,
                                                                                              onComplete: completeEdit,
                                                                                            ));
                                                                                }),
                                                                            ],
                                                                          );
                                                                          if (isGallery) return inner;
                                                                          return ClipPath(
                                                                            clipper: TailClipper(
                                                                              isFromMe: message.isFromMe!,
                                                                              showTail: !e.isPkPass &&
                                                                                  message.showTail(newerMessage) &&
                                                                                  e.part == controller.parts.length - 1,
                                                                              connectLower: iOS
                                                                                  ? false
                                                                                  : (e.part != 0 &&
                                                                                          e.part !=
                                                                                              controller.parts.length -
                                                                                                  1) ||
                                                                                      (e.part == 0 &&
                                                                                          controller.parts.length > 1),
                                                                              connectUpper: iOS ? false : e.part != 0,
                                                                            ),
                                                                            child: inner,
                                                                          );
                                                                        },
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                // Reactions are in the inner Stack so they are always
                                                                // positioned relative to the bubble, not the sticker
                                                                MessageReactions(
                                                                  messageParts: messageParts,
                                                                  part: e,
                                                                  chatGuid: chat.guid,
                                                                  reactionsForPart: reactionsForPart,
                                                                ),
                                                              ],
                                                            ),
                                                            // Stickers are in the outer Stack so they contribute to
                                                            // the message holder's size but don't affect bubble alignment
                                                            StickerObserver(
                                                              messageParts: messageParts,
                                                              part: e,
                                                              cvController: widget.cvController,
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  // swipe to reply
                                                  if (canSwipeToReply &&
                                                      !message.isGroupEvent &&
                                                      !e.isUnsent &&
                                                      !widget.isReplyThread &&
                                                      index < replyOffsets.length)
                                                    Obx(() => SlideToReply(
                                                        width: replyOffsets[index].value.abs(),
                                                        isFromMe: message.isFromMe!)),
                                                ].conditionalReverse(message.isFromMe!),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // message properties (replies, edits, effect)
                                  Padding(
                                    padding: showAvatar || alwaysShowAvatars
                                        ? EdgeInsets.only(left: 35.0 * avatarScale)
                                        : EdgeInsets.zero,
                                    child:
                                        MessageProperties(globalKey: keys.length > index ? keys[index] : null, part: e),
                                  ),
                                ],
                              ),
                            )),
                        // delivered / read receipt
                        DeliveredIndicatorObserver(tapped: tapped),
                      ],
                    ),
                  ),
                  if (isFromMe && !message.isGroupEvent) SelectCheckbox(controller: widget.cvController),
                  ErrorIndicatorObserver(chat: chat, service: service),
                  // slide to view timestamp
                  if (iOS) MessageTimestamp(controller: controller, cvController: widget.cvController),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Custom painter to draw a simple vertical line for the reply thread
/// connecting through the message sender
class _ReplyLinePainter extends CustomPainter {
  final Color color;
  final bool isFromMe;

  _ReplyLinePainter({required this.color, required this.isFromMe});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw vertical line at the same position as the reply line
    // Position depends on message direction: left side if from me, right side if not
    final x = isFromMe ? 35.0 : size.width - 35;
    canvas.drawLine(
      Offset(x, -5),
      Offset(x, size.height - (!isFromMe ? 0 : 5)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ReplyLinePainter oldDelegate) => oldDelegate.color != color || oldDelegate.isFromMe != isFromMe;
}
