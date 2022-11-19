import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
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
  double textFieldSize = 0;

  @override
  void initState() {
    super.initState();
    controller.sendFunc = send;
    KeyboardVisibilityController().onChange.listen((bool visible) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        final box = controller.textFieldKey.currentContext?.findRenderObject() as RenderBox?;
        textFieldSize = box?.size.height ?? 0;
        final textFieldPos = box?.localToGlobal(Offset.zero);
        if (visible) {
          setState(() {
            offset = 10;
          });
        } else {
          if (textFieldSize != 0 && textFieldPos != null) {
            setState(() {
              offset = Get.height - textFieldPos.dy - textFieldSize;
            });
          }
        }
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
      setState(() {
        tween = Tween<double>(
          begin: 0.9,
          end: 0,
        );
        control = Control.play;
        message = _message;
      });
    }
    super.updateWidget(tuple);
  }

  @override
  Widget build(BuildContext context) {
    final typicalWidth = ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30;
    return AnimatedPositioned(
      duration: Duration(milliseconds: message != null ? 400 : 0),
      bottom: message != null ? textFieldSize + offset + 15 : offset,
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
          duration: Duration(milliseconds: message != null ? 150 : 0),
          curve: Curves.linear,
          builder: (context, value, child) {
            return ClipPath(
              clipper: TailClipper(
                isFromMe: true,
                showTail: true,
                connectLower: false,
                connectUpper: false,
              ),
              child: AnimatedContainer(
                constraints: BoxConstraints(
                  maxWidth: max(ns.width(context) * value, typicalWidth),
                  minWidth: ns.width(context) * value > typicalWidth ? ns.width(context) * value : 0.0,
                  minHeight: 30,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(const EdgeInsets.only(right: 10)),
                color: context.theme.colorScheme.primary.darkenAmount(0.2),
                duration: Duration(milliseconds: ns.width(context) * value > typicalWidth ? 0 : 150),
                child: RichText(
                  text: TextSpan(
                    children: buildMessageSpans(
                      context,
                      MessagePart(part: 0, text: message!.text),
                      message!,
                    ),
                  ),
                )
              ),
            );
          },
        ),
      ),
    );
  }
}
