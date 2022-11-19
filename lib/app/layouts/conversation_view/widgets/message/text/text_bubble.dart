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
  Message? get olderMessage => controller.oldMessage;
  Message? get newerMessage => controller.newMessage;

  @override
  void initState() {
    forceDelete = false;
    super.initState();
  }

  List<Color> getBubbleColors() {
    List<Color> bubbleColors = [context.theme.colorScheme.properSurface, context.theme.colorScheme.properSurface];
    if (ss.settings.colorfulBubbles.value && !message.isFromMe!) {
      if (message.handle?.color == null) {
        bubbleColors = toColorGradient(message.handle?.address);
      } else {
        bubbleColors = [
          HexColor(message.handle!.color!),
          HexColor(message.handle!.color!).lightenAmount(0.075),
        ];
      }
    }
    return bubbleColors;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30,
        minHeight: 30,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0)),
      color: message.isFromMe!
          ? context.theme.colorScheme.primary.darkenAmount(message.guid!.startsWith("temp") ? 0.2 : 0)
          : null,
      decoration: message.isFromMe! ? null : BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.bottomCenter,
          end: AlignmentDirectional.topCenter,
          colors: getBubbleColors(),
        ),
      ),
      child: FutureBuilder<List<InlineSpan>>(
        future: buildEnrichedMessageSpans(
          context,
          part,
          message,
          colorOverride: ss.settings.colorfulBubbles.value && !message.isFromMe!
              ? getBubbleColors().first.oppositeLightenOrDarken(50) : null,
        ),
        initialData: buildMessageSpans(
          context,
          part,
          message,
          colorOverride: ss.settings.colorfulBubbles.value && !message.isFromMe!
              ? getBubbleColors().first.oppositeLightenOrDarken(50) : null,
        ),
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
    );
  }
}
