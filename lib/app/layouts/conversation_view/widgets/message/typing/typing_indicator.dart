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
    Key? key,
    required this.visible,
    this.scale = 1.0,
  }) : super(key: key);

  final bool visible;
  final double scale;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends OptimizedState<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
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
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: widget.visible ? (iOS || cm.activeChat == null ? ClipPath(
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
                    buildCupertinoDot(2),
                    buildCupertinoDot(1),
                    buildCupertinoDot(0),
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
            child: ContactAvatarWidget(
              handle: cm.activeChat!.chat.participants.first,
              size: 25,
              fontSize: context.theme.textTheme.bodyMedium!.fontSize!,
              borderThickness: 0.1,
            ),
          ),
          buildMaterialDot(2),
          buildMaterialDot(1),
          buildMaterialDot(0),
        ],
        mainAxisSize: MainAxisSize.min,
      )) : const SizedBox.shrink(),
    );
  }

  Widget buildCupertinoDot(int index) => AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final amt = (math.sin(animation.value + (index) * math.pi / 4).abs() * 20).clamp(1, 20).toDouble();
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

  Widget buildMaterialDot(int index) => AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      return Padding(
        padding: EdgeInsets.only(bottom: (math.sin(animation.value + (index) * math.pi / 4).abs() * 20).clamp(1, 20).toDouble()),
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
