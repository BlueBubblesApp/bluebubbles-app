import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class ReactionWidget extends StatelessWidget {
  const ReactionWidget({
    Key? key,
    required this.messageIsFromMe,
    required this.reactionIsFromMe,
    required this.reactionType,
  }) : super(key: key);

  final bool messageIsFromMe;
  final bool reactionIsFromMe;
  final String reactionType;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: messageIsFromMe ? Alignment.topRight : Alignment.topLeft,
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -1,
          left: messageIsFromMe ? 0 : -1,
          right: !messageIsFromMe ? 0 : -1,
          child: ClipPath(
            clipper: ReactionBorderClipper(isFromMe: messageIsFromMe),
            child: Container(
              width: 34.5,
              height: 34.5,
              color: context.theme.colorScheme.background,
            ),
          ),
        ),
        ClipPath(
          clipper: ReactionClipper(isFromMe: messageIsFromMe),
          child: Container(
            width: 32.5,
            height: 32.5,
            color: reactionIsFromMe ? context.theme.colorScheme.primary : context.theme.colorScheme.properSurface,
            alignment: messageIsFromMe ? Alignment.topRight : Alignment.topLeft,
            child: SizedBox(
              width: 32.5*0.8,
              height: 32.5*0.8,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(6.5),
                  child: SvgPicture.asset(
                    'assets/reactions/$reactionType-black.svg',
                    color: reactionType == "love"
                        ? Colors.pink
                        : (reactionIsFromMe ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.properOnSurface),
                  ),
                )
              ),
            )
          )
        )
      ],
    );
  }
}

