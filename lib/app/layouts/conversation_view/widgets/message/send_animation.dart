import 'dart:async';
import 'dart:math';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:tuple/tuple.dart';

class SendAnimation extends CustomStateful<ConversationViewController> {
  const SendAnimation({Key? key, required super.parentController}) : super(key: key);

  @override
  CustomState createState() => _SendAnimationState();
}

class _SendAnimationState extends CustomState<SendAnimation, Tuple6<List<PlatformFile>, String, String, String?, int?, String?>, ConversationViewController> {
  Message? message;
  Tween<double> tween = Tween<double>(begin: 1, end: 0);
  Control control = Control.stop;
  double textFieldSize = 0;

  @override
  void initState() {
    super.initState();
    controller.sendFunc = send;
    updateObx(() {
      final box = controller.textFieldKey.currentContext?.findRenderObject() as RenderBox?;
      textFieldSize = box?.size.height ?? 0;
    });
  }

  Future<void> send(Tuple6<List<PlatformFile>, String, String, String?, int?, String?> tuple) async {
    // do not add anything above this line, the attachments must be extracted first
    final attachments = List<PlatformFile>.from(tuple.item1);
    final text = tuple.item2;
    final subject = tuple.item3;
    final replyGuid = tuple.item4;
    final part = tuple.item5;
    final effectId = tuple.item6;
    await controller.scrollToBottom();
    if (ss.settings.sendSoundPath.value != null) {
      PlayerController controller = PlayerController();
      controller.preparePlayer(
        ss.settings.sendSoundPath.value!, 1.0
      ).then((_) => controller.startPlayer());
    }
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
      await outq.queue(OutgoingItem(
        type: QueueType.sendAttachment,
        chat: controller.chat,
        message: message,
      ));
    }

    if (text.isNotEmpty || subject.isNotEmpty) {
      final _message = Message(
        text: text.isEmpty && subject.isNotEmpty ? subject : text,
        subject: text.isEmpty && subject.isNotEmpty ? null : subject,
        threadOriginatorGuid: replyGuid,
        threadOriginatorPart: "${part ?? 0}:0:0",
        expressiveSendStyleId: effectId,
        dateCreated: DateTime.now(),
        hasAttachments: false,
        isFromMe: true,
        handleId: 0,
        hasDdResults: true,
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
    final typicalWidth = message?.isBigEmoji ?? false
        ? ns.width(context) : ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 40;
    return AnimatedPositioned(
      duration: Duration(milliseconds: message != null ? 400 : 0),
      bottom: message != null ? textFieldSize + 17.5 + (controller.showTypingIndicator.value ? 50 : 0) : 0,
      right: 5,
      curve: Curves.easeInOutCubic,
      onEnd: () async {
        if (message != null) {
          await Future.delayed(const Duration(milliseconds: 100));
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
                  minHeight: 40,
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15)
                    .add(EdgeInsets.only(
                      left: message!.isFromMe! || message!.isBigEmoji ? 0 : 10,
                      right: message!.isFromMe! && !message!.isBigEmoji ? 10 : 0
                    )),
                color: !message!.isBigEmoji ? context.theme.colorScheme.primary.darkenAmount(0.2) : null,
                duration: Duration(milliseconds: ns.width(context) * value > typicalWidth ? 0 : 150),
                child: Center(
                  widthFactor: 1,
                  child: Padding(
                    padding: message!.fullText.length == 1 ? const EdgeInsets.only(left: 3, right: 3) : EdgeInsets.zero,
                    child: RichText(
                      text: TextSpan(
                        children: buildMessageSpans(
                          context,
                          MessagePart(part: 0, text: message!.text, subject: message!.subject),
                          message!,
                        ),
                      ),
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
