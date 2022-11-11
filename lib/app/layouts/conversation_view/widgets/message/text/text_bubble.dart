import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TextBubble extends CustomStateful<MessageWidgetController> {
  TextBubble({
    Key? key,
    required super.parentController,
    required this.message,
  }) : super(key: key);

  final MessagePart message;

  @override
  _TextBubbleState createState() => _TextBubbleState();
}

class _TextBubbleState extends CustomState<TextBubble, void, MessageWidgetController> {
  MessagePart get part => widget.message;
  Message get message => controller.message;
  Message? get olderMessage => controller.oldMwc?.message;
  Message? get newerMessage => controller.newMwc?.message;

  @override
  void initState() {
    forceDelete = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: TailClipper(
        isFromMe: message.isFromMe!,
        showTail: message.showTail(newerMessage) && part.part == controller.parts.length - 1,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30,
          minHeight: 30,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0)),
        color: message.isFromMe! ? context.theme.colorScheme.primary.darkenAmount(message.guid!.startsWith("temp") ? 0.2 : 0) : context.theme.colorScheme.properSurface,
        child: FutureBuilder<List<InlineSpan>>(
          future: buildEnrichedMessageSpans(context, part, message),
          initialData: buildMessageSpans(context, part, message),
          builder: (context, snapshot) {
            if (snapshot.data != null) {
              return RichText(
                text: TextSpan(
                  children: snapshot.data!,
                ),
              );
            }
            return const SizedBox.shrink();
          }
        ),
      ),
    );
  }
}
