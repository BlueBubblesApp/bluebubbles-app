import 'dart:math' as math;

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/typing/typing_clipper.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({
    super.key,
    this.visible,
    this.controller,
    this.scale = 1.0,
  });

  final bool? visible;
  final ConversationViewController? controller;
  final double scale;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends OptimizedState<TypingIndicator> {

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: (widget.controller?.showTypingIndicator.value ?? widget.visible)! ? (iOS || !GlobalChatService.hasActiveChat ? ClipPath(
        clipper: const TypingClipper(),
        child: Container(
          height: 50,
          width: 80,
          color: context.theme.colorScheme.properSurface,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 15,
                right: 12,
                child: Row(
                  children: [
                    AnimatedDot(index: 2),
                    AnimatedDot(index: 1),
                    AnimatedDot(index: 0),
                  ],
                  mainAxisSize: MainAxisSize.min,
                ),
              )
            ],
          ),
        ),
      ) : Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10),
            child: Obx(() => ContactAvatarWidget(
              handle: GlobalChatService.activeChat!.observables.participants.first,
              size: 25,
              fontSize: context.theme.textTheme.bodyMedium!.fontSize!,
              borderThickness: 0.1,
            )),
          ),
          AnimatedDot(index: 2),
          AnimatedDot(index: 1),
          AnimatedDot(index: 0),
        ],
        mainAxisSize: MainAxisSize.min,
      )) : const SizedBox.shrink(),
    );
  }
}

class AnimatedDot extends StatefulWidget {
  final int index;
  AnimatedDot({required this.index});

  @override
  State<AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends OptimizedState<AnimatedDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700), animationBehavior: AnimationBehavior.preserve);
    _controller.addStatusListener((state) {
      if (state == AnimationStatus.completed && mounted) {
        _controller.forward(from: 0.0);
      }
    });

    animation = Tween(
      begin: 0.0,
      end: math.pi,
    ).animate(_controller);

    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (iOS) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final amt = (math.sin(animation.value + (widget.index) * math.pi / 4).abs() * 20).clamp(1, 20).toDouble();
          return Container(
            decoration: BoxDecoration(
              color: ts.inDarkMode(context)
                  ? context.theme.colorScheme.properSurface.lightenPercent(amt)
                  : context.theme.colorScheme.properSurface.darkenPercent(amt),
              shape: BoxShape.circle,
            ),
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 2),
          );
        },
      );
    } else {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Padding(
            padding: EdgeInsets.only(bottom: (math.sin(animation.value + (widget.index) * math.pi / 4).abs() * 20).clamp(1, 20).toDouble()),
            child: Container(
              decoration: BoxDecoration(
                color: context.theme.colorScheme.properSurface,
                shape: BoxShape.circle,
              ),
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
            ),
          );
        },
      );
    }
  }
}