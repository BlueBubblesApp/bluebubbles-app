import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';

class TextBubble extends StatefulWidget {
  const TextBubble({
    super.key,
    required this.message,
    this.subjectOnly = false,
  });

  final MessagePart message;
  final bool subjectOnly;

  @override
  State<StatefulWidget> createState() => _TextBubbleState();
}

class _TextBubbleState extends State<TextBubble> with ThemeHelpers {
  late MessageState _ms;
  MessageState get controller => _ms;

  MessagePart get part => widget.message;
  Message get message => controller.message;
  MessageEffect get effect => effectOf(message);

  late MovieTween tween;
  final rxAnim = Rx<Control>(Control.stop);
  Worker? _effectWorker;

  @override
  void initState() {
    super.initState();
    _ms = MessageStateScope.readStateOnce(context);
    if (effect == MessageEffect.gentle) {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 1), curve: Curves.easeInOut)
            .tween("size", 1.0.tweenTo(1.0))
        ..scene(
                begin: const Duration(milliseconds: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut)
            .tween("size", 0.0.tweenTo(0.5))
        ..scene(
                begin: const Duration(milliseconds: 1000),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut)
            .tween("size", 0.5.tweenTo(1.0));
    } else {
      tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
            .tween("size", 1.0.tweenTo(1.0));
    }
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_effectWorker == null && effect == MessageEffect.gentle) {
      final ms = MessageStateScope.maybeOf(context);
      if (ms != null) {
        _effectWorker = ever(ms.playEffectPart, (int? partIdx) {
          if (partIdx == part.part && mounted) {
            rxAnim.value = Control.playFromStart;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _effectWorker?.dispose();
    super.dispose();
  }

  List<Color> getBubbleColors(bool selected) {
    if (selected && !iOS) {
      return [context.theme.colorScheme.tertiaryContainer, context.theme.colorScheme.tertiaryContainer];
    }
    final receivedColor = (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor ??
        context.theme.colorScheme.surfaceContainerHighest;
    List<Color> bubbleColors = [receivedColor, receivedColor];
    if (SettingsSvc.settings.colorfulBubbles.value && !message.isFromMe!) {
      // Read from HandleState reactively (called inside Obx so registers dependency).
      final colorStr = controller.sender?.color.value;
      final address = controller.sender?.handle.address;
      if (colorStr == null) {
        bubbleColors = toColorGradient(address);
      } else {
        bubbleColors = [
          HexColor(colorStr),
          HexColor(colorStr).lightenAmount(0.075),
        ];
      }
    }
    return bubbleColors;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Observe selection state and temp message state
      final selected = !iOS && (controller.cvController?.selected.any((m) => m.guid == message.guid) ?? false);
      // Use MessageState observables for proper reactivity
      final isTempMessage = controller.isSending.value;
      final isFromMe = controller.isFromMe.value;

      return Container(
        constraints: BoxConstraints(
          maxWidth: message.isBigEmoji
              ? NavigationSvc.width(context)
              : NavigationSvc.width(context) * MessageState.maxBubbleSizeFactor - 40,
          minHeight: 36,
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15).add(EdgeInsets.only(
            left: isFromMe || message.isBigEmoji ? 0 : 10, right: isFromMe && !message.isBigEmoji ? 10 : 0)),
        color: isFromMe && !message.isBigEmoji
            ? (selected
                ? context.theme.colorScheme.tertiaryContainer
                : context.theme.colorScheme
                    .bubble(context, message.chat.target?.isIMessage ?? true)
                    .darkenAmount(isTempMessage ? 0.2 : 0))
            : null,
        decoration: isFromMe || message.isBigEmoji
            ? null
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.bottomCenter,
                  end: AlignmentDirectional.topCenter,
                  colors: getBubbleColors(selected),
                ),
              ),
        // alignment: Alignment.center,
        child: FutureBuilder<List<InlineSpan>>(
            future: buildEnrichedMessageSpans(
              context,
              part,
              message,
              colorOverride: selected
                  ? context.theme.colorScheme.onTertiaryContainer
                  : SettingsSvc.settings.colorfulBubbles.value && !isFromMe
                      ? getBubbleColors(selected).first.oppositeLightenOrDarken(90)
                      : null,
              hideBodyText: widget.subjectOnly,
            ),
            initialData: buildMessageSpans(
              context,
              part,
              message,
              colorOverride: selected
                  ? context.theme.colorScheme.onTertiaryContainer
                  : SettingsSvc.settings.colorfulBubbles.value && !isFromMe
                      ? getBubbleColors(selected).first.oppositeLightenOrDarken(90)
                      : null,
              hideBodyText: widget.subjectOnly,
            ),
            builder: (context, snapshot) {
              if (snapshot.data != null) {
                if (effect == MessageEffect.gentle) {
                  return Obx(() => CustomAnimationBuilder<Movie>(
                        control: rxAnim.value,
                        tween: tween,
                        duration: const Duration(milliseconds: 1800),
                        animationStatusListener: (status) {
                          if (status == AnimationStatus.completed) {
                            rxAnim.value = Control.stop;
                          }
                        },
                        builder: (context, anim, child) {
                          final value1 = anim.get("size");
                          return Transform.scale(scale: value1, alignment: Alignment.center, child: child);
                        },
                        child: RichText(
                          text: TextSpan(
                            children: snapshot.data!,
                          ),
                        ),
                      ));
                }
                return Center(
                  widthFactor: 1,
                  child: Padding(
                      padding:
                          message.fullText.length == 1 ? const EdgeInsets.only(left: 3, right: 3) : EdgeInsets.zero,
                      child: RichText(
                        text: TextSpan(
                          children: snapshot.data!,
                        ),
                      )),
                );
              }
              return const SizedBox.shrink();
            }),
      );
    });
  }
}
