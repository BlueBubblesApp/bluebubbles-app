import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/app/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:tuple/tuple.dart';

class SendAnimation extends CustomStateful<ConversationViewController> {
  const SendAnimation({Key? key, required super.parentController}) : super(key: key);

  @override
  _SendAnimationState createState() => _SendAnimationState();
}

class _SendAnimationState extends CustomState<SendAnimation, Tuple6<List<PlatformFile>, String, String, String?, int?, String?>, ConversationViewController> {
  Message? message;
  Tween<double> tween = Tween<double>(begin: 1, end: 0);
  double offset = 0;
  Control control = Control.stop;

  @override
  void initState() {
    super.initState();
    controller.sendFunc = send;
    KeyboardVisibilityController().onChange.listen((bool visible) async {
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted) {
        final textFieldSize = (controller.textFieldKey.currentContext?.findRenderObject() as RenderBox?)?.size.height;
        setState(() {
          offset = (textFieldSize ?? 0) > 300 ? 300 : 0;
        });
      }
    });
  }

  Future<void> send(Tuple6<List<PlatformFile>, String, String, String?, int?, String?> tuple) async {
    await controller.scrollToBottom();

    final attachments = tuple.item1;
    final text = tuple.item2;
    final subject = tuple.item3;
    final replyGuid = tuple.item4;
    final part = tuple.item5;
    final effectId = tuple.item6;
    for (int i = 0; i < attachments.length; i++) {
      final file = attachments[i];
      final message = Message(
        text: "",
        dateCreated: DateTime.now(),
        hasAttachments: true,
        attachments: [
          Attachment(
            isOutgoing: true,
            uti: "public.jpg",
            bytes: file.bytes,
            transferName: file.name,
            totalBytes: file.size,
          ),
        ],
        isFromMe: true,
        handleId: 0,
      );
      message.generateTempGuid();
      message.attachments.first!.guid = message.guid;
      final completer = Completer<void>();
      outq.queue(OutgoingItem(
        type: QueueType.sendAttachment,
        chat: controller.chat,
        message: message,
        completer: completer,
      ));
      await completer.future;
    }

    if (text.isNotEmpty || subject.isNotEmpty) {
      final _message = Message(
        text: text,
        subject: subject,
        threadOriginatorGuid: replyGuid,
        threadOriginatorPart: "${part ?? 0}:0:0",
        expressiveSendStyleId: effectId,
        dateCreated: DateTime.now(),
        hasAttachments: true,
        isFromMe: true,
        handleId: 0,
      );
      _message.generateTempGuid();
      outq.queue(OutgoingItem(
        type: QueueType.sendMessage,
        chat: controller.chat,
        message: _message,
      ));
      final constraints = BoxConstraints(
        maxWidth: ns.width(context) * MessageWidgetMixin.MAX_SIZE,
        minHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize!,
        maxHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize!,
      );
      final renderParagraph = RichText(
        text: TextSpan(
          text: _message.text,
          style: context.theme.extension<BubbleText>()!.bubbleText,
        ),
        maxLines: 1,
      ).createRenderObject(context);
      final renderParagraph2 = RichText(
        text: TextSpan(
          text: _message.subject ?? "",
          style: context.theme.extension<BubbleText>()!.bubbleText,
        ),
        maxLines: 1,
      ).createRenderObject(context);
      final size = renderParagraph.getDryLayout(constraints);
      final size2 = renderParagraph2.getDryLayout(constraints);
      setState(() {
        tween = Tween<double>(
            begin: ns.width(context) - 30,
            end: min(max(size.width, size2.width) + 80,
                ns.width(context) * MessageWidgetMixin.MAX_SIZE + 40));
        control = Control.play;
        message = _message;
      });
    }
    super.updateWidget(tuple);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: Duration(milliseconds: 400),
      bottom: message != null ? 130 + offset : 10 + offset,
      right: 5,
      curve: Curves.easeInOutCubic,
      onEnd: () {
        if (message != null) {
          setState(() {
            tween = Tween<double>(begin: 1, end: 0);
            control = Control.stop;
            message = null;
          });
        }
      },
      child: Visibility(
        visible: message != null,
        child: CustomAnimationBuilder<double>(
            control: control,
            tween: tween,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return SentMessageHelper.buildMessageWithTail(
                context,
                message,
                true,
                false,
                message?.isBigEmoji ?? false,
                MessageWidgetMixin.buildMessageSpansAsync(context, message),
                customWidth: (message?.hasAttachments ?? false) &&
                    (message?.text?.isEmpty ?? true) &&
                    (message?.subject?.isEmpty ?? true)
                    ? null
                    : value,
                customColor: (message?.hasAttachments ?? false) &&
                    (message?.text?.isEmpty ?? true) &&
                    (message?.subject?.isEmpty ?? true)
                    ? Colors.transparent
                    : null,
                customContent: child,
              );
            },
            child: (message?.hasAttachments ?? false) &&
                (message?.text?.isEmpty ?? true) &&
                (message?.subject?.isEmpty ?? true)
                ? MessageAttachments(
              message: message,
              showTail: true,
              showHandle: false,
            ) : null
        ),
      ),
    );
  }
}
