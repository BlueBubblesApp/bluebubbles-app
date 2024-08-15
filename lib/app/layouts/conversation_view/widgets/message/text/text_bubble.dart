import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';

class TextBubble extends CustomStateful<MessageWidgetController> {
  TextBubble({
    super.key,
    required super.parentController,
    required this.message,
    this.subjectOnly = false,
  });

  final MessagePart message;
  final bool subjectOnly;

  @override
  CustomState createState() => _TextBubbleState();
}

class _TextBubbleState extends CustomState<TextBubble, void, MessageWidgetController> {
  MessagePart get part => widget.message;
  Message get message => controller.message;
  String get effectStr => effectMap.entries.firstWhereOrNull((e) => e.value == message.expressiveSendStyleId)?.key ?? "unknown";
  MessageEffect get effect => stringToMessageEffect[effectStr] ?? MessageEffect.none;

  late MovieTween tween;
  Control anim = Control.stop;
  late bool selected = controller.cvController?.isSelected(message.guid!) ?? false;

  @override
  void initState() {
    forceDelete = false;
    if (effect == MessageEffect.gentle) {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 1), curve: Curves.easeInOut)
            .tween("size", 1.0.tweenTo(1.0))
        ..scene(begin: const Duration(milliseconds: 1), duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
            .tween("size", 0.0.tweenTo(0.5))
        ..scene(begin: const Duration(milliseconds: 1000), duration: const Duration(milliseconds: 800), curve: Curves.easeInOut)
            .tween("size", 0.5.tweenTo(1.0));
    } else {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
            .tween("size", 1.0.tweenTo(1.0));
    }
    eventDispatcher.stream.listen((event) async {
      if (event.item1 == 'play-bubble-effect' && event.item2 == '${part.part}/${message.guid}' && effect == MessageEffect.gentle) {
        setState(() {
          anim = Control.playFromStart;
        });
      }
    });
    if (controller.cvController != null && !iOS) {
      ever<List<Message>>(controller.cvController!.selected, (event) {
        if (controller.cvController!.isSelected(message.guid!) && !selected) {
          setState(() {
            selected = true;
          });
        } else if (!controller.cvController!.isSelected(message.guid!) && selected) {
          setState(() {
            selected = false;
          });
        }
      });
    }
    super.initState();
  }

  List<Color> getBubbleColors() {
    if (selected && !iOS) return [context.theme.colorScheme.tertiaryContainer, context.theme.colorScheme.tertiaryContainer];
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
        maxWidth: message.isBigEmoji ? ns.width(context) : ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 40,
        minHeight: 40,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15)
        .add(EdgeInsets.only(
          left: message.isFromMe! || message.isBigEmoji ? 0 : 10,
          right: message.isFromMe! && !message.isBigEmoji ? 10 : 0
        )),
      color: message.isFromMe! && !message.isBigEmoji
          ? (selected ? context.theme.colorScheme.tertiaryContainer : context.theme.colorScheme.primary.darkenAmount(message.guid!.startsWith("temp") ? 0.1 : 0))
          : null,
      decoration: message.isFromMe! || message.isBigEmoji ? null : BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.bottomCenter,
          end: AlignmentDirectional.topCenter,
          colors: getBubbleColors(),
        ),
      ),
      // alignment: Alignment.center,
      child: FutureBuilder<List<InlineSpan>>(
        future: buildEnrichedMessageSpans(
          context,
          part,
          message,
          colorOverride: selected ? context.theme.colorScheme.onTertiaryContainer
              : ss.settings.colorfulBubbles.value && !message.isFromMe!
              ? getBubbleColors().first.oppositeLightenOrDarken(75) : null,
          hideBodyText: widget.subjectOnly,
        ),
        initialData: buildMessageSpans(
          context,
          part,
          message,
          colorOverride: selected ? context.theme.colorScheme.onTertiaryContainer
              : ss.settings.colorfulBubbles.value && !message.isFromMe!
              ? getBubbleColors().first.oppositeLightenOrDarken(75) : null,
          hideBodyText: widget.subjectOnly,
        ),
        builder: (context, snapshot) {
          if (snapshot.data != null) {
            if (effect == MessageEffect.gentle) {
              return CustomAnimationBuilder<Movie>(
                control: anim,
                tween: tween,
                duration: const Duration(milliseconds: 1800),
                animationStatusListener: (status) {
                  if (status == AnimationStatus.completed) {
                    setState(() {
                      anim = Control.stop;
                    });
                  }
                },
                builder: (context, anim, child) {
                  final value1 = anim.get("size");
                  return Transform.scale(
                    scale: value1,
                    alignment: Alignment.center,
                    child: child
                  );
                },
                child: RichText(
                  text: TextSpan(
                    children: snapshot.data!,
                  ),
                ),
              );
            }
            return Center(
              widthFactor: 1,
              child: Padding(
                padding: message.fullText.length == 1 ? const EdgeInsets.only(left: 3, right: 3) : EdgeInsets.zero,
                child: RichText(
                  text: TextSpan(
                    children: snapshot.data!,
                  ),
                )
              ),
            );
          }
          return const SizedBox.shrink();
        }
      ),
    );
  }
}
