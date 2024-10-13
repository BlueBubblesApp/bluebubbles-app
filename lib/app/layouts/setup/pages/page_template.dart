import 'dart:async';

import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:simple_animations/simple_animations.dart';

class SetupPageTemplate extends StatelessWidget {
  SetupPageTemplate({
    required this.title,
    required this.subtitle,
    this.aboveTitle,
    this.belowSubtitle,
    this.customTitle,
    this.customSubtitle,
    this.customButton,
    this.customMiddle,
    this.titleWrapper,
    this.subtitleWrapper,
    this.contentWrapper,
    this.buttonWrapper,
    this.onNextPressed,
  });

  final String title;
  final String subtitle;
  final Widget? aboveTitle;
  final Widget? belowSubtitle;
  final Widget? customTitle;
  final Widget? customSubtitle;
  final Widget? customButton;
  final Widget? customMiddle;
  final Widget Function(Widget)? titleWrapper;
  final Widget Function(Widget)? subtitleWrapper;
  final Widget Function(Widget)? contentWrapper;
  final Widget Function(Widget)? buttonWrapper;
  final FutureOr<bool> Function()? onNextPressed;
  final SetupViewController controller = Get.find<SetupViewController>();

  @override
  Widget build(BuildContext context) {
    final buttons = PageButtons(
      title: title,
      customButton: customButton,
      onNextPressed: onNextPressed,
    );
    return LayoutBuilder(
      builder: (context, size) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  PageContent(
                    aboveTitle: aboveTitle,
                    customTitle: customTitle,
                    title: title,
                    customSubtitle: customSubtitle,
                    subtitle: subtitle,
                    belowSubtitle: belowSubtitle,
                    titleWrapper: titleWrapper,
                    subtitleWrapper: subtitleWrapper,
                    contentWrapper: contentWrapper,
                  ),
                  if (customMiddle != null) customMiddle!,
                  if (buttonWrapper != null)
                    buttonWrapper!.call(buttons),
                  if (buttonWrapper == null)
                    buttons,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class PageContent extends StatelessWidget {
  const PageContent({
    super.key,
    required this.aboveTitle,
    required this.customTitle,
    required this.title,
    required this.customSubtitle,
    required this.subtitle,
    required this.belowSubtitle,
    this.titleWrapper,
    this.subtitleWrapper,
    this.contentWrapper,
  });

  final Widget? aboveTitle;
  final Widget? customTitle;
  final String title;
  final Widget? customSubtitle;
  final String subtitle;
  final Widget? belowSubtitle;
  final Widget Function(Widget)? titleWrapper;
  final Widget Function(Widget)? subtitleWrapper;
  final Widget Function(Widget)? contentWrapper;
  
  @override
  Widget build(BuildContext context) {
    final titleW = customTitle ?? Padding(
      padding: const EdgeInsets.all(8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: context.width * 2 / 3,
          child: Text(
              title,
              style: context.theme.textTheme.displayMedium!.apply(
                fontWeightDelta: 2,
              ).copyWith(height: 1.35, color: context.theme.colorScheme.onBackground)
          ),
        ),
      ),
    );
    final subtitleW = customSubtitle ?? Padding(
      padding: const EdgeInsets.all(8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
            subtitle,
            style: context.theme.textTheme.bodyLarge!.apply(
              fontSizeDelta: 1.5,
              color: context.theme.colorScheme.outline,
            ).copyWith(height: 2)
        ),
      ),
    );
    final content = Column(
      children: [
        if (aboveTitle != null)
          aboveTitle!,
        if (aboveTitle != null)
          const SizedBox(height: 10),
        if (titleWrapper != null)
          titleWrapper!.call(titleW),
        if (titleWrapper == null)
          titleW,
        if (subtitleWrapper != null)
          subtitleWrapper!.call(subtitleW),
        if (subtitleWrapper == null)
          subtitleW,
        if (belowSubtitle != null)
          belowSubtitle!,
      ],
    );
    if (contentWrapper != null) {
      return contentWrapper!.call(content);
    } else {
      return content;
    }
  }
}

class PageButtons extends StatelessWidget {
  PageButtons({
    super.key,
    required this.title,
    required this.customButton,
    required this.onNextPressed,
  });

  final String title;
  final Widget? customButton;
  final FutureOr<bool> Function()? onNextPressed;
  final Control animation = Control.mirror;
  final Tween<double> tween = Tween<double>(begin: 0, end: 5);
  final SetupViewController controller = Get.find<SetupViewController>();

  @override
  Widget build(BuildContext context) {
    return customButton ?? Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        title == "Welcome to BlueBubbles" ? const SizedBox.shrink() : Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
            ),
          ),
          height: 40,
          padding: const EdgeInsets.all(2),
          child: ElevatedButton(
            style: ButtonStyle(
              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
              ),
              backgroundColor: WidgetStateProperty.all(context.theme.colorScheme.background),
              shadowColor: WidgetStateProperty.all(context.theme.colorScheme.background),
              maximumSize: WidgetStateProperty.all(const Size(200, 36)),
              minimumSize: WidgetStateProperty.all(const Size(30, 30)),
            ),
            onPressed: () async {
              previousPage();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: context.theme.colorScheme.onBackground, size: 20),
                const SizedBox(width: 10),
                Text("Back", style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: context.theme.colorScheme.onBackground)),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              colors: [HexColor('2772C3'), HexColor('5CA7F8').darkenPercent(5)],
            ),
          ),
          height: 40,
          child: ElevatedButton(
            style: ButtonStyle(
              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
              ),
              backgroundColor: WidgetStateProperty.all(Colors.transparent),
              shadowColor: WidgetStateProperty.all(Colors.transparent),
              maximumSize: WidgetStateProperty.all(const Size(200, 36)),
              minimumSize: WidgetStateProperty.all(const Size(30, 30)),
            ),
            onPressed: () async {
              final proceed = (await onNextPressed?.call()) ?? true;
              if (proceed) nextPage();
            },
            child: Shimmer.fromColors(
              baseColor: Colors.white70,
              highlightColor: Colors.white,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 30.0),
                    child: Text("Next", style: context.theme.textTheme.bodyLarge!.apply(fontSizeFactor: 1.1, color: Colors.white)),
                  ),
                  Positioned(
                    left: 40,
                    child: CustomAnimationBuilder<double>(
                      control: animation,
                      tween: tween,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, anim, _) {
                        return Padding(
                          padding: EdgeInsets.only(left: anim),
                          child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void nextPage() {
    controller.pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void previousPage() {
    controller.pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
