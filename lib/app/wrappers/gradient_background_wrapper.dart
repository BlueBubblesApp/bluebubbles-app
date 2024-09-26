import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';

class GradientBackground extends CustomStateful<ConversationViewController> {
  final Widget child;

  GradientBackground({
    Key? key,
    required this.child,
    required ConversationViewController controller,
  }) : super(parentController: controller);

  @override
  State<StatefulWidget> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends CustomState<GradientBackground, void, ConversationViewController> with WidgetsBindingObserver {
  late final RxBool adjustBackground = RxBool(ts.isGradientBg(Get.context!));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    adjustBackground.value = ts.isGradientBg(Get.context!);
  }

  @override
  Widget build(BuildContext context) {
    if (!adjustBackground.value) {
      return widget.child;
    }
    return MirrorAnimationBuilder<Movie>(
      tween: ts.gradientTween.value,
      curve: Curves.fastOutSlowIn,
      duration: const Duration(seconds: 3),
      builder: (context, anim, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              stops: [
                anim.get("color1"),
                anim.get("color2")
              ], colors: [
                context.theme.colorScheme
                  .bubble(context, GlobalChatService.getChat(controller.chatGuid)!.chat.isIMessage)
                  .withOpacity(0.5),
                context.theme.colorScheme.background,
              ]
            )
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}