import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class MessageProperties extends CustomStateful<MessageWidgetController> {
  MessageProperties({
    Key? key,
    required super.parentController,
    required this.part,
    this.globalKey,
  }) : super(key: key);

  final MessagePart part;
  final GlobalKey? globalKey;

  @override
  _MessagePropertiesState createState() => _MessagePropertiesState();
}

class _MessagePropertiesState extends CustomState<MessageProperties, void, MessageWidgetController> {
  Message get message => controller.message;
  MessagesService get service => ms(message.chat.target!.guid);

  @override
  void initState() {
    forceDelete = false;
    super.initState();
  }

  List<TextSpan> getProperties() {
    final properties = <TextSpan>[];
    final replyList = service.struct.threads(message.guid!).where((e) => e.threadOriginatorPart?.startsWith(widget.part.part.toString()) ?? false);
    if (message.expressiveSendStyleId != null) {
      final effect = effectMap.entries.firstWhereOrNull((element) => element.value == message.expressiveSendStyleId)?.key ?? "unknown";
      properties.add(TextSpan(
        text: "↺ sent with $effect",
        recognizer: TapGestureRecognizer()..onTap = () {
          HapticFeedback.mediumImpact();
          if ((stringToMessageEffect[effect] ?? MessageEffect.none).isBubble) {
            /*if (effect == "invisible ink" && animController == Control.playFromStart) {
              setState(() {
                animController = Control.stop;
              });
            } else {
              setState(() {
                animController = Control.playFromStart;
              });
            }*/
          } else if (widget.globalKey != null) {
            eventDispatcher.emit('play-effect', {
              'type': effect,
              'size': widget.globalKey!.globalPaintBounds(context),
            });
          }
        }
      ));
    }
    if (replyList.isNotEmpty) {
      properties.add(TextSpan(
        text: "${replyList.length} repl${replyList.length > 1 ? "ies" : "y"}",
        recognizer: TapGestureRecognizer()..onTap = () {
          showReplyThread(context, message, widget.part, service);
        }
      ));
    }
    if (widget.part.isEdited) {
      properties.add(TextSpan(
        text: "Edited",
        recognizer: TapGestureRecognizer()..onTap = () {
          controller.showEdits.toggle();
        }
      ));
    }

    return properties;
  }

  @override
  Widget build(BuildContext context) {
    final props = getProperties();
    return AnimatedSize(
      curve: Curves.easeInOut,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 250),
      child: props.isNotEmpty ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15).add(const EdgeInsets.only(top: 3)),
        child: Text.rich(
          TextSpan(
            children: intersperse(const TextSpan(text: " • "), props).toList(),
          ),
          style: context.theme.textTheme.labelSmall!.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold),
        ),
      ) : const SizedBox.shrink(),
    );
  }
}
