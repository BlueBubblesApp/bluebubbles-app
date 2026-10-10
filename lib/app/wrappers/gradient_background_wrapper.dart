import 'dart:async';

import 'package:bluebubbles/app/components/wallpaper/wallpaper.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';

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

  /// How long the window has to hold one size before the static background is re-decoded for it.
  static const Duration _resizeSettleDelay = Duration(milliseconds: 300);

  /// The window geometry the static background was last decoded for. On desktop a drag-resize
  /// changes `MediaQuery.sizeOf` every frame, and each distinct size is a distinct `ResizeImage`
  /// key, so following it live meant a fresh disk read and full decode per frame. The provider is
  /// built from this instead, and it only moves once the size has settled (see [_settledGeometry]).
  (Size, double)? _settledGeometry;
  Timer? _resizeDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chatState = ChatsSvc.getChatState(controller.chat.guid);
  }

  @override
  void dispose() {
    _resizeDebounce?.cancel();
    super.dispose();
  }

  /// The (logical size, device pixel ratio) to decode the static background for.
  ///
  /// Mobile returns the live value: its size only changes on rotation or fold, which is a single
  /// step. Desktop returns the last settled value while a resize is in flight, so the already
  /// decoded image keeps drawing (`BoxFit.cover` stretches it) and the decode happens once, after
  /// the window has held still for [_resizeSettleDelay].
  (Size, double) _geometryToDecodeFor(BuildContext context) {
    final (Size, double) live = (MediaQuery.sizeOf(context), MediaQuery.devicePixelRatioOf(context));
    if (!kIsDesktop) return live;

    // The first real size is decoded for immediately; the debounce only applies to changes after
    // that. An empty size (window not laid out yet) is passed through without being remembered,
    // so the first proper size is not treated as a resize and delayed.
    final (Size, double)? settled = _settledGeometry;
    if (settled == null || settled.$1.isEmpty) {
      if (!live.$1.isEmpty) _settledGeometry = live;
      return live;
    }
    if (settled == live) {
      _resizeDebounce?.cancel();
      _resizeDebounce = null;
      return settled;
    }

    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(_resizeSettleDelay, () {
      _resizeDebounce = null;
      if (!mounted) return;
      setState(() => _settledGeometry = live);
    });
    return settled;
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
              // The conversation Scaffold shrinks its body to avoid the
              // keyboard, and some dynamic wallpapers (e.g. the
              // `flutter_moving_background`-backed one) reset their entire
              // animation state whenever the space they're laid out in
              // resizes -- so every keyboard show/hide was visibly
              // glitching the wallpaper. Pin its height to the full window
              // instead of the space actually available (which shrinks for
              // the keyboard) so it never sees that as a resize; the
              // ancestor `Stack`'s default clip keeps the overflow
              // invisible.
              return LayoutBuilder(
                builder: (context, constraints) {
                  return OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: MediaQuery.sizeOf(context).height,
                    maxHeight: MediaQuery.sizeOf(context).height,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: DynamicWallpaperView(
                        wallpaperId: _chatState?.dynamicWallpaperId.value,
                        config: _chatState?.dynamicWallpaperConfig.value,
                      ),
                    ),
                  );
                },
              );
            }

            final String? bgPath = _chatState?.customBackgroundPath.value;

            if (bgPath != null) {
              final (Size size, double dpr) = _geometryToDecodeFor(context);
              return Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    // Decoded at window size, not file size: see static_wallpaper_image.dart.
                    image: chatBackgroundImageProviderForWindow(bgPath, size, dpr),
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
