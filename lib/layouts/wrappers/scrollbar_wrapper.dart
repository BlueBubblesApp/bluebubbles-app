import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_improved_scrolling/flutter_improved_scrolling.dart';
import 'package:get/get.dart';

class ScrollbarWrapper extends StatelessWidget {
  ScrollbarWrapper({
    Key? key,
    required this.child,
    this.showScrollbar = false,
    this.reverse = false,
    required this.controller,
  }) : super(key: key);

  final Widget child;
  final bool showScrollbar;
  final bool reverse;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) => !kIsDesktop && !kIsWeb ? child : Obx(() => ImprovedScrolling(
    enableMMBScrolling: true,
    mmbScrollConfig: MMBScrollConfig(
      customScrollCursor: DefaultCustomScrollCursor(
        cursorColor: context.textTheme.labelLarge!.color!,
        backgroundColor: Colors.white,
        borderColor: context.textTheme.headlineMedium!.color!,
      ),
    ),
    enableCustomMouseWheelScrolling: SettingsManager().settings.betterScrolling.value && (kIsDesktop || kIsWeb),
    customMouseWheelScrollConfig: CustomMouseWheelScrollConfig(
      scrollAmountMultiplier: (reverse ? -1 : 1) * SettingsManager().settings.betterScrollingMultiplier.value,
      scrollDuration: Duration(milliseconds: 140),
      mouseWheelTurnsThrottleTimeMs: 35,
    ),
    scrollController: controller,
    child: showScrollbar
      ? RawScrollbar(
          controller: controller,
          thumbColor: context.theme.colorScheme.secondary.withOpacity(0.7),
          thickness: 10,
          radius: Radius.circular(5),
          child: child,
        )
      : ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: showScrollbar),
          child: child,
        ),
    ),
  );
}
