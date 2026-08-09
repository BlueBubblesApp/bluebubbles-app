import 'package:bluebubbles/app/components/wallpaper/wallpaper.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:universal_io/io.dart';

class GradientBackground extends CustomStateful<ConversationViewController> {
  final Widget child;

  const GradientBackground({
    super.key,
    required this.child,
    required ConversationViewController controller,
  }) : super(parentController: controller);

  @override
  State<StatefulWidget> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends CustomState<GradientBackground, void, ConversationViewController>
    with WidgetsBindingObserver {
  late final RxBool adjustBackground = RxBool(ThemeSvc.isGradientBg(Get.context!));
  ChatState? _chatState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatState = ChatsSvc.getChatState(controller.chat.guid);
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    adjustBackground.value = ThemeSvc.isGradientBg(Get.context!);
  }

  @override
  Widget build(BuildContext context) {
    // Use a Stack so widget.child is always at a fixed position in the element
    // tree. This prevents Flutter from tearing down the child subtree (and
    // disposing FocusNodes) when the background decoration changes reactively.
    return Stack(
      children: [
        Positioned.fill(
          child: Obx(() {
            if (_chatState?.wallpaperType.value == ChatWallpaperType.dynamic) {
              return DynamicWallpaperView(
                wallpaperId: _chatState?.dynamicWallpaperId.value,
                config: _chatState?.dynamicWallpaperConfig.value,
              );
            }

            final String? bgPath = _chatState?.customBackgroundPath.value;

            if (bgPath != null) {
              return Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: FileImage(File(bgPath)),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    onError: (_, _) {},
                  ),
                ),
              );
            }

            if (!adjustBackground.value) {
              return const SizedBox.shrink();
            }

            return MirrorAnimationBuilder<Movie>(
              tween: ThemeSvc.gradientTween.value,
              curve: Curves.fastOutSlowIn,
              duration: const Duration(seconds: 3),
              builder: (context, anim, _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      stops: [anim.get("color1"), anim.get("color2")],
                      colors: [
                        context.theme.colorScheme.bubble(context, controller.chat.isIMessage).withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
        widget.child,
      ],
    );
  }
}
