import 'package:bluebubbles/helpers/helpers.dart';
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
  Widget build(BuildContext context) => !kIsDesktop && !kIsWeb
      ? child
      : ImprovedScrolling(
          enableKeyboardScrolling: true,
          enableMMBScrolling: true,
          mmbScrollConfig: MMBScrollConfig(
            customScrollCursor: DefaultCustomScrollCursor(
              cursorColor: context.textTheme.labelLarge!.color!,
              backgroundColor: context.theme.colorScheme.background,
              borderColor: context.textTheme.headlineMedium!.color!,
            ),
          ),
          scrollController: controller,
          child: showScrollbar
              ? RawScrollbar(
                  controller: controller,
                  thumbColor: context.theme.colorScheme.properOnSurface.withOpacity(0.3),
                  thickness: 10,
                  radius: const Radius.circular(5),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: !showScrollbar),
                    child: child,
                  ),
                )
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: showScrollbar),
                  child: child,
                ),
        );
}
