import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/slide_to_reply.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/text_bubble.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/delivered_indicator.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/message_timestamp.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/timestamp_separator.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/message_attachment.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
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
      if (message.fullText.isNotEmpty) {
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
              .map((e) => attributedBodyToMessagePart(e.text!.values.first)).toList());
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

  List<MessagePart> attributedBodyToMessagePart(AttributedBody e) {
    final mainString = message.attributedBody.first.string;
    final list = <MessagePart>[];
    message.attributedBody.first.runs.forEachIndexed((i, e) {
      if (e.attributes?.messagePart == null) return;
      final existingPart = list.firstWhereOrNull((element) => element.part == e.attributes!.messagePart!);
      // this should only happen if there is a mention in the middle breaking up the text
      if (existingPart != null) {
        existingPart.text = (existingPart.text ?? "") + mainString.substring(e.range.first, e.range.first + e.range.last);
        if (e.hasMention) {
          existingPart.mention = Mention(
            mentionedAddress: e.attributes?.mention,
            range: [e.range.first, e.range.first + e.range.last],
          );
        }
      } else {
        list.add(MessagePart(
          subject: i == 0 ? message.subject : null,
          text: e.isAttachment ? null : mainString.substring(e.range.first, e.range.first + e.range.last),
          attachments: e.isAttachment ? [ms(widget.cvController.chat.guid).struct.getAttachment(e.attributes!.attachmentGuid!)!] : [],
          mention: !e.hasMention ? null : Mention(
            mentionedAddress: e.attributes?.mention,
            range: [e.range.first, e.range.first + e.range.last],
          ),
          part: e.attributes!.messagePart!,
        ));
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TimestampSeparator(olderMessage: olderMessage, message: message),
        Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: message.isFromMe! ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  ...messageParts.mapIndexed((index, e) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                        child: e.attachments.isEmpty ? TextBubble(
                          parentController: controller,
                          message: e,
                        ) : AttachmentHolder(
                          parentController: controller,
                          message: e,
                        ),
                      ),
                      if (canSwipeToReply)
                        Obx(() => SlideToReply(width: replyOffsets[index].value.abs())),
                    ].conditionalReverse(message.isFromMe!),
                  )),
                  if (message.isFromMe!)
                    DeliveredIndicator(parentController: controller),
                ],
              ),
            ),
            MessageTimestamp(controller: controller, cvController: widget.cvController),
          ],
        ),
      ],
    );
  }
}
