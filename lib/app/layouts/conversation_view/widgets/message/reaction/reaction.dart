import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class ReactionWidget extends StatelessWidget {
  const ReactionWidget({
    Key? key,
    required this.messageIsFromMe,
    required this.reactionIsFromMe,
    required this.reactionType,
    this.reactions,
  }) : super(key: key);

  final bool messageIsFromMe;
  final bool reactionIsFromMe;
  final String reactionType;
  final List<Message>? reactions;

  static const double iosSize = 35;

  @override
  Widget build(BuildContext context) {
    if (ss.settings.skin.value != Skins.iOS) {
      return Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: reactionIsFromMe ? context.theme.colorScheme.primary : context.theme.colorScheme.properSurface,
          border: Border.all(color: context.theme.colorScheme.background),
          shape: BoxShape.circle,
        ),
        child: GestureDetector(
          onTap: () {
            if (reactions == null) return;
            for (Message m in reactions!) {
              if (!m.isFromMe!) {
                m.handle ??= m.getHandle();
              }
            }
            Navigator.push(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 500),
                pageBuilder: (context, animation, secondaryAnimation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 1.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                    child: Theme(
                      data: context.theme.copyWith(
                        // in case some components still use legacy theming
                        primaryColor: context.theme.colorScheme.bubble(context, true),
                        colorScheme: context.theme.colorScheme.copyWith(
                          primary: context.theme.colorScheme.bubble(context, true),
                          onPrimary: context.theme.colorScheme.onBubble(context, true),
                          surface: ss.settings.monetTheming.value == Monet.full ? null : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                          onSurface: ss.settings.monetTheming.value == Monet.full ? null : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          Positioned(
                            bottom: 10,
                            left: 15,
                            right: 15,
                            child: ReactionDetails(reactions: reactions!)
                          ),
                        ],
                      ),
                    ),
                  );
                },
                fullscreenDialog: true,
                opaque: false,
                barrierDismissible: true,
              ),
            );
          },
          child: Center(
            child: Text(
              ReactionTypes.reactionToEmoji[reactionType] ?? "X",
              style: const TextStyle(fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ),
        )
      );
    }
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
              width: iosSize + 2,
              height: iosSize + 2,
              color: context.theme.colorScheme.background,
            ),
          ),
        ),
        ClipPath(
          clipper: ReactionClipper(isFromMe: messageIsFromMe),
          child: Container(
            width: iosSize,
            height: iosSize,
            color: reactionIsFromMe ? context.theme.colorScheme.primary : context.theme.colorScheme.properSurface,
            alignment: messageIsFromMe ? Alignment.topRight : Alignment.topLeft,
            child: SizedBox(
              width: iosSize*0.8,
              height: iosSize*0.8,
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

