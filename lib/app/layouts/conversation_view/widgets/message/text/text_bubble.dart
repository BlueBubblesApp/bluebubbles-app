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
        color: message.isFromMe! ? context.theme.colorScheme.primary : context.theme.colorScheme.properSurface,
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

class TailClipper extends CustomClipper<Path>{
  final bool isFromMe;
  final bool showTail;

  TailClipper({
    required this.isFromMe,
    required this.showTail,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final double start = isFromMe ? 0 : 10;
    final double end = isFromMe ? size.width - 10 : size.width;
    path.moveTo(start, 20);
    if (!isFromMe && showTail) {
      path.lineTo(start, size.height - 10);
      path.arcToPoint(Offset(0, size.height), radius: const Radius.circular(10));
      // intersect slightly more than 45 deg on the arc
      path.arcToPoint(Offset(start + 6.547, size.height - 5.201), radius: const Radius.circular(20), clockwise: false);
      path.arcToPoint(Offset(start + 20, size.height), radius: const Radius.circular(20), clockwise: false);
    } else {
      path.lineTo(start, size.height - 20);
      path.arcToPoint(Offset(start + 20, size.height), radius: const Radius.circular(20), clockwise: false);
    }
    path.lineTo(end - 20, size.height);
    if (isFromMe && showTail) {
      // intersect slightly more than 45 deg on the arc
      path.arcToPoint(Offset(end - 6.547, size.height - 5.201), radius: const Radius.circular(20), clockwise: false);
      path.arcToPoint(Offset(size.width, size.height), radius: const Radius.circular(20), clockwise: false);
      path.arcToPoint(Offset(end, size.height - 10), radius: const Radius.circular(10));
    } else {
      path.arcToPoint(Offset(end, size.height - 20), radius: const Radius.circular(20), clockwise: false);
    }
    path.lineTo(end, 20);
    path.arcToPoint(Offset(end - 20, 0), radius: const Radius.circular(20), clockwise: false);
    path.lineTo(start + 20, 0);
    path.arcToPoint(Offset(start, 20), radius: const Radius.circular(20), clockwise: false);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant TailClipper oldClipper) {
    return showTail != oldClipper.showTail;
  }
}
