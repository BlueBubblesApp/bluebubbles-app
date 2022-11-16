import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/sticker_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/chat_event/chat_event.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/interactive_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/message_properties.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/message_sender.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/slide_to_reply.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/text_bubble.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/delivered_indicator.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/message_timestamp.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/timestamp_separator.dart';
import 'package:bluebubbles/app/widgets/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class MessageHolder extends CustomStateful<MessageWidgetController> {
  MessageHolder({
    Key? key,
    required this.cvController,
    this.oldMessageGuid,
    this.newMessageGuid,
    required this.message,
  }) : super(key: key, parentController: mwc(message));

  final Message message;
  final String? oldMessageGuid;
  final String? newMessageGuid;
  final ConversationViewController cvController;

  @override
  _MessageHolderState createState() => _MessageHolderState();
}

class _MessageHolderState extends CustomState<MessageHolder, void, MessageWidgetController> {
  Message get message => controller.message;
  Message? get olderMessage => controller.oldMwc?.message;
  Message? get newerMessage => controller.newMwc?.message;
  Chat get chat => widget.cvController.chat;
  bool get canSwipeToReply => ss.settings.enablePrivateAPI.value && ss.settings.swipeToReply.value && chat.isIMessage;
  bool get showSender => !message.isGroupEvent && (!message.sameSender(olderMessage)
      || (olderMessage == null || !message.dateCreated!.isWithin(olderMessage!.dateCreated!, minutes: 30)));

  List<MessagePart> messageParts = [];
  List<RxDouble> replyOffsets = [];
  bool gaveHapticFeedback = false;

  @override
  void initState() {
    forceDelete = false;
    controller.oldMessageGuid = widget.oldMessageGuid;
    controller.newMessageGuid = widget.newMessageGuid;
    super.initState();
    buildMessageParts();
    // fallback - build from the actual message
    if (messageParts.isEmpty) {
      messageParts.addAll(message.attachments.map((e) => MessagePart(
        attachments: [e!],
        part: 0,
      )));
      if (message.fullText.isNotEmpty || message.isGroupEvent) {
        messageParts.add(MessagePart(
          subject: message.subject,
          text: message.text,
          part: 0,
        ));
      }
    }
    controller.parts = messageParts;
    replyOffsets = List.filled(messageParts.length, 0.0.obs);
  }

  void buildMessageParts() {
    // go through the attributed body
    if (message.attributedBody.firstOrNull?.runs.isNotEmpty ?? false) {
      messageParts = attributedBodyToMessagePart(message.attributedBody.first);
    }
    // add edits
    if (message.messageSummaryInfo.firstOrNull?.editedParts.isNotEmpty ?? false) {
      for (int part in message.messageSummaryInfo.first.editedParts) {
        final edits = message.messageSummaryInfo.first.editedContent[part.toString()] ?? [];
        final existingPart = messageParts.firstWhereOrNull((element) => element.part == part);
        if (existingPart != null) {
          existingPart.edits.addAll(edits
              .where((e) => e.text?.values.isNotEmpty ?? false)
              .map((e) => attributedBodyToMessagePart(e.text!.values.first).firstOrNull)
              .where((e) => e != null).map((e) => e!).toList());
          existingPart.edits.removeLast();
        }
      }
    }
    // add unsends
    if (message.messageSummaryInfo.firstOrNull?.retractedParts.isNotEmpty ?? false) {
      for (int part in message.messageSummaryInfo.first.retractedParts) {
        messageParts.add(MessagePart(
          part: part,
          isUnsent: true,
        ));
      }
    }
    messageParts.sort((a, b) => a.part.compareTo(b.part));
  }

  List<MessagePart> attributedBodyToMessagePart(AttributedBody body) {
    final mainString = body.string;
    final list = <MessagePart>[];
    body.runs.forEachIndexed((i, e) {
      if (e.attributes?.messagePart == null) return;
      final existingPart = list.firstWhereOrNull((element) => element.part == e.attributes!.messagePart!);
      // this should only happen if there is a mention in the middle breaking up the text
      if (existingPart != null) {
        final newText = mainString.substring(e.range.first, e.range.first + e.range.last);
        existingPart.text = (existingPart.text ?? "") + newText;
        if (e.hasMention) {
          existingPart.mentions.add(Mention(
            mentionedAddress: e.attributes?.mention,
            range: [existingPart.text!.indexOf(newText), existingPart.text!.indexOf(newText) + e.range.last],
          ));
          existingPart.mentions.sort((a, b) => a.range.first.compareTo(b.range.first));
        }
      } else {
        list.add(MessagePart(
          subject: i == 0 ? message.subject : null,
          text: e.isAttachment ? null : mainString.substring(e.range.first, e.range.first + e.range.last),
          attachments: e.isAttachment ? [
            ms(widget.cvController.chat.guid).struct.getAttachment(e.attributes!.attachmentGuid!)
                ?? Attachment.findOne(e.attributes!.attachmentGuid!)
          ].where((e) => e != null).map((e) => e!).toList() : [],
          mentions: !e.hasMention ? [] : [Mention(
            mentionedAddress: e.attributes?.mention,
            range: [0, e.range.last],
          )],
          part: e.attributes!.messagePart!,
        ));
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final stickers = message.associatedMessages.where((e) => e.associatedMessageType == "sticker");
    final reactions = message.associatedMessages.where((e) => ReactionTypes.toList().contains(e.associatedMessageType));
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // large timestamp between messages
        TimestampSeparator(olderMessage: olderMessage, message: message),
        // use stack so avatar can be placed at bottom
        Stack(
          alignment: Alignment.bottomLeft,
          clipBehavior: Clip.none,
          children: [
            // avatar, if needed
            if (message.showTail(newerMessage) && (chat.isGroup || ss.settings.alwaysShowAvatars.value) && !message.isFromMe!)
              Padding(
                padding: const EdgeInsets.only(left: 5.0),
                child: ContactAvatarWidget(
                  handle: message.handle,
                  size: 30,
                  fontSize: context.theme.textTheme.bodyLarge!.fontSize!,
                  borderThickness: 0.1,
                ),
              ),
            Row(
              children: [
                // shift over by avatar width
                if (chat.isGroup)
                  const SizedBox(width: 35),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: message.isFromMe! ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // message column
                      ...messageParts.mapIndexed((index, e) => Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: message.isFromMe! ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          // show sender, if needed
                          if (chat.isGroup && !message.isFromMe! && showSender && e.part == (messageParts.firstWhereOrNull((e) => !e.isUnsent)?.part))
                            MessageSender(olderMessage: olderMessage, message: message),
                          // add a box to account for height of reactions if
                          // a sender wasn't added and there are reactions
                          if (reactions.where((s) => (s.associatedMessagePart ?? 0) == e.part).isNotEmpty
                              && !(chat.isGroup && !message.isFromMe! && showSender && e.part == messageParts.firstWhereOrNull((e) => !e.isUnsent)?.part))
                            const SizedBox(height: 15),
                          // add previous edits if needed
                          if (e.isEdited)
                            Obx(() => AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              alignment: Alignment.bottomCenter,
                              curve: controller.showEdits.value ? Curves.easeOutBack : Curves.easeOut,
                              child: controller.showEdits.value ? Opacity(
                                opacity: 0.75,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: e.edits.map((edit) => TextBubble(
                                    parentController: controller,
                                    message: edit,
                                  )).toList(),
                                ),
                              ) : Container(height: 0, constraints: BoxConstraints(
                                maxWidth: ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30
                              )),
                            )),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // show group event
                              if (message.isGroupEvent || e.isUnsent)
                                ChatEvent(
                                  part: e,
                                  message: message,
                                ),
                              // otherwise show content
                              if (!message.isGroupEvent && !e.isUnsent)
                                Stack(
                                  alignment: Alignment.center,
                                  fit: StackFit.loose,
                                  clipBehavior: Clip.none,
                                  children: [
                                    // actual message content
                                    GestureDetector(
                                      behavior: HitTestBehavior.deferToChild,
                                      // todo onTap: kIsDesktop || kIsWeb ? () => tapped.value = !tapped.value : null,
                                      onHorizontalDragUpdate: !canSwipeToReply ? null : (details) {
                                        if ((message.isFromMe! && details.delta.dx > 0) || (!message.isFromMe! && details.delta.dx < 0)) {
                                          return;
                                        }
                                        final offset = replyOffsets[index];
                                        offset.value += details.delta.dx * 0.5;
                                        if (!gaveHapticFeedback && offset.value.abs() >= SlideToReply.replyThreshold) {
                                          HapticFeedback.lightImpact();
                                          gaveHapticFeedback = true;
                                        } else if (offset.value.abs() < SlideToReply.replyThreshold) {
                                          gaveHapticFeedback = false;
                                        }
                                      },
                                      onHorizontalDragEnd: !canSwipeToReply ? null : (details) {
                                        final offset = replyOffsets[index];
                                        if (offset.value.abs() >= SlideToReply.replyThreshold) {
                                          widget.cvController.replyToMessage = message;
                                        }
                                        offset.value = 0;
                                      },
                                      onHorizontalDragCancel: !canSwipeToReply ? null : () {
                                        replyOffsets[index].value = 0;
                                      },
                                      child: message.hasApplePayloadData || message.isLegacyUrlPreview || message.isInteractive ? InteractiveHolder(
                                        parentController: controller,
                                        message: e,
                                      ) : e.attachments.isEmpty ? TextBubble(
                                        parentController: controller,
                                        message: e,
                                      ) : AttachmentHolder(
                                        parentController: controller,
                                        message: e,
                                      ),
                                    ),
                                    // show stickers on top
                                    StickerHolder(stickerMessages: stickers.where((s) => (s.associatedMessagePart ?? 0) == e.part)),
                                    // show reactions on top
                                    if (message.isFromMe!)
                                      Positioned(
                                        top: -15,
                                        left: -20,
                                        child: ReactionHolder(
                                          reactions: reactions.where((s) => (s.associatedMessagePart ?? 0) == e.part),
                                          message: message,
                                        ),
                                      ),
                                    if (!message.isFromMe!)
                                      Positioned(
                                        top: -15,
                                        right: -20,
                                        child: ReactionHolder(
                                          reactions: reactions.where((s) => (s.associatedMessagePart ?? 0) == e.part),
                                          message: message,
                                        ),
                                      ),
                                  ],
                                ),
                              // swipe to reply
                              if (canSwipeToReply && !message.isGroupEvent && !e.isUnsent)
                                Obx(() => SlideToReply(width: replyOffsets[index].value.abs())),
                            ].conditionalReverse(message.isFromMe!),
                          ),
                          // message properties (replies, edits, effect)
                          MessageProperties(parentController: controller, part: e),
                        ],
                      )),
                      // delivered / read receipt
                      if (message.isFromMe!)
                        DeliveredIndicator(parentController: controller),
                    ],
                  ),
                ),
                // slide to view timestamp
                MessageTimestamp(controller: controller, cvController: widget.cvController),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
