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
    super.key,
    required super.parentController,
    required this.part,
    this.globalKey,
  });

  final MessagePart part;
  final GlobalKey? globalKey;

  @override
  CustomState createState() => _MessagePropertiesState();
}

class _MessagePropertiesState extends CustomState<MessageProperties, void, MessageWidgetController> {
  Message get message => controller.message;
  MessagesService get service => ms(controller.cvController?.chat.guid ?? cm.activeChat!.chat.guid);

  @override
  void initState() {
    forceDelete = false;
    super.initState();
  }

  List<TextSpan> getProperties() {
    final properties = <TextSpan>[];
    final replyList = service.struct.threads(message.guid!, widget.part.part, returnOriginator: false);
    if (message.expressiveSendStyleId != null) {
      final effect = effectMap.entries.firstWhereOrNull((element) => element.value == message.expressiveSendStyleId)?.key ?? "unknown";
      properties.add(TextSpan(
        text: "↺ sent with $effect",
        recognizer: TapGestureRecognizer()..onTap = () {
          if (stringToMessageEffect[effect] == MessageEffect.echo) {
            showSnackbar("Notice", "Echo animation is not supported at this time.");
            return;
          }
          HapticFeedback.mediumImpact();
          if ((stringToMessageEffect[effect] ?? MessageEffect.none).isBubble) {
            eventDispatcher.emit('play-bubble-effect', '${widget.part.part}/${message.guid}');
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
          if (controller.cvController == null) return;
          showReplyThread(context, message, widget.part, service, controller.cvController!);
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
