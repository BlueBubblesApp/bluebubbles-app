import 'dart:math';

import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/layouts/setup/pages/page_template.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_animations/simple_animations.dart';

class WelcomePage extends StatefulWidget {
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends OptimizedState<WelcomePage> with TickerProviderStateMixin {
  late final AnimationController _titleController;
  late final AnimationController _subtitleController;
  final confettiController = ConfettiController(duration: const Duration(milliseconds: 500));
  final GlobalKey key = GlobalKey();
  final Control controller = Control.mirror;
  final Tween<double> tween = Tween<double>(begin: 0, end: 5);
  late final Animation<double> opacityTitle;
  late final Animation<double> opacitySubtitle;

  double height = 250;

  @override
  void initState() {
    super.initState();
    _titleController = AnimationController(duration: const Duration(seconds: 1), vsync: this, animationBehavior: AnimationBehavior.preserve);
    _subtitleController = AnimationController(duration: const Duration(seconds: 1), vsync: this, animationBehavior: AnimationBehavior.preserve);

    opacityTitle = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _titleController, curve: Curves.easeInOut));
    opacitySubtitle = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _subtitleController, curve: Curves.easeInOut));

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _titleController.forward();
      await Future.delayed(const Duration(milliseconds: 500));
      _subtitleController.forward();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SetupPageTemplate(
      title: "Welcome to BlueBubbles",
      subtitle: "Experience a clean, customizable iMessage client across all platforms",
      aboveTitle: Theme(
        data: context.theme.copyWith(
          // in case some components still use legacy theming
          primaryColor: context.theme.colorScheme.bubble(context, true),
          colorScheme: context.theme.colorScheme.copyWith(
            primary: context.theme.colorScheme.bubble(context, true),
            onPrimary: context.theme.colorScheme.onBubble(context, true),
            surface: (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
            onSurface: (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
          ),
        ),
        child: FadeTransition(
          opacity: opacityTitle,
          child: Theme(
            data: context.theme.copyWith(
              // in case some components still use legacy theming
              primaryColor: context.theme.colorScheme.bubble(context, true),
              colorScheme: context.theme.colorScheme.copyWith(
                primary: context.theme.colorScheme.bubble(context, true),
                onPrimary: context.theme.colorScheme.onBubble(context, true),
                surface: ss.settings.monetTheming.value == Monet.full
                    ? null
                    : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                onSurface: ss.settings.monetTheming.value == Monet.full
                    ? null
                    : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
              ),
            ),
            child: Builder(
              builder: (context) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: context.theme.colorScheme.surface.lightenOrDarken(65),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ConfettiWidget(
                          confettiController: confettiController,
                          blastDirection: pi / 2,
                          blastDirectionality: BlastDirectionality.explosive,
                          emissionFrequency: 0.35,
                          canvas: Size(context.width - 16, height + 50),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  ContactAvatarWidget(
                                    handle: Handle(
                                      id: Random.secure().nextInt(10000),
                                    ),
                                    size: iOS ? 30 : 35,
                                    fontSize: context.theme.textTheme.bodyLarge!.fontSize!,
                                    borderThickness: 0.1,
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipPath(
                                        clipper: TailClipper(
                                          isFromMe: false,
                                          showTail: false,
                                          connectLower: false,
                                          connectUpper: false,
                                        ),
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            maxWidth: 100,
                                            maxHeight: 100,
                                          ),
                                          padding: const EdgeInsets.only(left: 10),
                                          color: context.theme.colorScheme.surface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      ClipPath(
                                        clipper: TailClipper(
                                          isFromMe: false,
                                          showTail: true,
                                          connectLower: false,
                                          connectUpper: false,
                                        ),
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            maxWidth: 140,
                                            minHeight: 40,
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(const EdgeInsets.only(left: 10)),
                                          color: context.theme.colorScheme.surface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          ClipPath(
                                            clipper: TailClipper(
                                              isFromMe: true,
                                              showTail: true,
                                              connectLower: false,
                                              connectUpper: false,
                                            ),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                maxWidth: 100,
                                                minHeight: 40,
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(const EdgeInsets.only(right: 10)),
                                              color: context.theme.colorScheme.primary,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              // todo dart fix confettiController.play();
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 15).add(const EdgeInsets.only(top: 3)),
                                              child: Text.rich(
                                                const TextSpan(
                                                  text: "↺ sent with confetti",
                                                ),
                                                style: context.theme.textTheme.labelSmall!.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          )
                                        ]
                                    ),
                                  ]
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            ),
          ),
        ),
      ),
      titleWrapper: (child) => FadeTransition(
        opacity: opacityTitle,
        child: child,
      ),
      subtitleWrapper: (child) => FadeTransition(
        opacity: opacitySubtitle,
        child: child,
      ),
      buttonWrapper: (child) => FadeTransition(
        opacity: opacitySubtitle,
        child: child,
      ),
      onNextPressed: () async {
        if ((fs.androidInfo?.version.sdkInt ?? 0) >= 33) {
          await Permission.notification.request();
        }
        return true;
      },
    );
  }
}
