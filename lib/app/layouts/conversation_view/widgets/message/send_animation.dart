import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:async_task/async_task_extension.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mime_type/mime_type.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:tuple/tuple.dart';

class SendAnimation extends CustomStateful<ConversationViewController> {
  const SendAnimation({super.key, required super.parentController});

  @override
  CustomState createState() => _SendAnimationState();
}

class _SendAnimationState
    extends CustomState<SendAnimation, Tuple6<List<PlatformFile>, String, String, String?, int?, String?>, ConversationViewController> {
  Message? message;
  Tween<double> tween = Tween<double>(begin: 1, end: 0);
  Control control = Control.stop;
  double textFieldSize = 0;

  double get focusInfoSize => (controller.focusInfoKey.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 0;

  @override
  void initState() {
    super.initState();
    controller.sendFunc = send;
    updateObx(() {
      final box = controller.textFieldKey.currentContext?.findRenderObject() as RenderBox?;
      textFieldSize = box?.size.height ?? 0;
    });
  }

  Future<void> send(Tuple6<List<PlatformFile>, String, String, String?, int?, String?> tuple, bool isAudioMessage) async {
    // do not add anything above this line, the attachments must be extracted first
    final attachments = List<PlatformFile>.from(tuple.item1);
    String text = tuple.item2;
    final subject = tuple.item3;
    final replyGuid = tuple.item4;
    final part = tuple.item5;
    final effectId = tuple.item6;
    if (ss.settings.scrollToBottomOnSend.value) {
      await controller.scrollToBottom();
    }
    if (ss.settings.sendSoundPath.value != null && !(isNullOrEmptyString(text) && isNullOrEmptyString(subject) && controller.pickedAttachments.isEmpty)) {
      if (kIsDesktop) {
        Player player = Player();
        await player.setVolume(ss.settings.soundVolume.value.toDouble());
        await player.open(Media(ss.settings.sendSoundPath.value!));
        player.stream.completed
            .firstWhere((completed) => completed)
            .then((_) async => Future.delayed(const Duration(milliseconds: 450), () async => await player.dispose()));
      } else {
        PlayerController controller = PlayerController();
        controller.preparePlayer(path: ss.settings.sendSoundPath.value!, volume: ss.settings.soundVolume.value / 100).then((_) => controller.startPlayer());
      }
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
            mimeType: mime(file.path),
            uti: "public.jpg",
            bytes: file.bytes,
            transferName: file.name,
            totalBytes: file.size,
          ),
        ],
        isFromMe: true,
        handleId: 0,
        threadOriginatorGuid: i == 0 ? replyGuid : null,
        threadOriginatorPart: i == 0 ? "${part ?? 0}:0:0" : null,
        expressiveSendStyleId: effectId,
      );
      message.generateTempGuid();
      message.attachments.first!.guid = message.guid;
      await outq.queue(OutgoingItem(type: QueueType.sendAttachment, chat: controller.chat, message: message, customArgs: {"audio": isAudioMessage}));
    }

    if (text.isNotEmpty || subject.isNotEmpty) {
      final textSplit = MentionTextEditingController.splitText(text);
      bool flag = false;
      final newText = [];
      if (textSplit.length > 1) {
        for (String word in textSplit) {
          if (word == MentionTextEditingController.escapingChar) flag = !flag;
          int? index = flag ? int.tryParse(word) : null;
          if (index != null) {
            final mention = controller.textController.mentionables[index];
            newText.add(mention);
            continue;
          }
          if (word == MentionTextEditingController.escapingChar) {
            continue;
          }
          newText.add(word.replaceAll(MentionTextEditingController.escapingChar, ""));
        }
        text = newText.join("");
      }
      int currentPos = 0;
      final _message = Message(
        text: text.isEmpty && subject.isNotEmpty ? subject : text,
        subject: text.isEmpty && subject.isNotEmpty ? null : subject,
        threadOriginatorGuid: attachments.isEmpty ? replyGuid : null,
        threadOriginatorPart: attachments.isEmpty ? "${part ?? 0}:0:0" : null,
        expressiveSendStyleId: effectId,
        dateCreated: DateTime.now(),
        hasAttachments: false,
        isFromMe: true,
        handleId: 0,
        hasDdResults: true,
        attributedBody: [
          if (textSplit.length > 1)
            AttributedBody(
              string: text,
              runs: newText.whereType<Mentionable>().isEmpty
                  ? []
                  : newText.map((e) {
                      if (e is Mentionable) {
                        final run = Run(
                            range: [currentPos, e.toString().length],
                            attributes: Attributes(
                              mention: e.address,
                              messagePart: 0,
                            ));
                        currentPos += e.toString().length;
                        return run;
                      } else {
                        final run = Run(
                          range: [currentPos, e.length],
                          attributes: Attributes(
                            messagePart: 0,
                          ),
                        );
                        currentPos += e.toString().length;
                        return run;
                      }
                    }).toList(),
            ),
        ],
      );
      _message.generateTempGuid();
      outq.queue(OutgoingItem(
        type: (_message.attributedBody.isNotEmpty) ? QueueType.sendMultipart : QueueType.sendMessage,
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
    final typicalWidth = message?.isBigEmoji ?? false ? ns.width(context) : ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 40;
    const duration = 450;
    const curve = Curves.easeInOut;
    const buttonSize = 88;
    final messageBoxSize = ns.width(context) - buttonSize;
    return AnimatedPositioned(
      duration: Duration(milliseconds: message != null ? duration : 0),
      bottom: message != null ? textFieldSize + focusInfoSize + 17.5 + (controller.showTypingIndicator.value ? 50 : 0) + (!iOS ? 15 : 0) : 0,
      right: samsung ? -37.5 : 5,
      curve: curve,
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
          duration: Duration(milliseconds: message != null ? duration : 0),
          builder: (context, linear, child) {
            var value = curve.transform(linear);
            var exp = Curves.easeIn.transform(linear);
            return Transform.scale(
              scale: (1-value) < .5 ? lerpDouble(1.1, .9, (1-value) / .5) : lerpDouble(.9, 1, (.5-value) / .5),
              alignment: Alignment.centerRight,
              child: ClipPath(
                clipper: TailClipper(
                  isFromMe: true,
                  showTail: true,
                  connectLower: false,
                  connectUpper: false,
                ),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: max(messageBoxSize * exp, typicalWidth),
                        minWidth: messageBoxSize * exp,
                        minHeight: 40,
                      ),
                      color: !message!.isBigEmoji ? context.theme.colorScheme.primary.withAlpha(((1 - value) * 255).toInt()) : null,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(EdgeInsets.only(
                        left: message!.isFromMe! || message!.isBigEmoji ? 0 : 10, right: message!.isFromMe! && !message!.isBigEmoji ? 10 : 0)),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: 1,
                        child: Padding(
                          padding: message!.fullText.length == 1 ? const EdgeInsets.only(left: 3, right: 3) : EdgeInsets.zero,
                          child: RichText(
                            text: TextSpan(
                              children: buildMessageSpans(
                                context,
                                MessagePart(part: 0, text: message!.text, subject: message!.subject),
                                message!,
                                colorOverride: Color.lerp(context.theme.colorScheme.properOnSurface, context.theme.colorScheme.onPrimary, 1 - value)
                              ),
                            ),
                          ),
                        ),
                      )
                    ),),
              ),
            );
          },
        ),
      ),
    );
  }
}