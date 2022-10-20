import 'dart:math';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/layouts/setup/pages/page_template.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';

class WelcomePage extends StatefulWidget {
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends OptimizedState<WelcomePage> with TickerProviderStateMixin {
  late final AnimationController _titleController;
  late final AnimationController _subtitleController;
  final confettiController = ConfettiController(duration: Duration(milliseconds: 500));
  final GlobalKey key = GlobalKey();
  final Control controller = Control.mirror;
  final Tween<double> tween = Tween<double>(begin: 0, end: 5);
  late final Animation<double> opacityTitle;
  late final Animation<double> opacitySubtitle;

  double height = 250;

  @override
  void initState() {
    super.initState();
    _titleController = AnimationController(duration: const Duration(seconds: 1), vsync: this);
    _subtitleController = AnimationController(duration: const Duration(seconds: 1), vsync: this);

    opacityTitle = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _titleController, curve: Curves.easeInOut));
    opacitySubtitle = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _subtitleController, curve: Curves.easeInOut));

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _titleController.forward();
      await Future.delayed(Duration(milliseconds: 500));
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
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: context.theme.colorScheme.properSurface,
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
                  Column(
                      key: key,
                      children: [
                        AbsorbPointer(
                          absorbing: true,
                          child: MessageWidget(
                            newerMessage: null,
                            olderMessage: null,
                            isFirstSentMessage: false,
                            showHandle: true,
                            showHero: false,
                            showReplies: false,
                            autoplayEffect: false,
                            message: Message(
                              guid: "redacted-mode-demo",
                              dateDelivered2: DateTime.now().toLocal(),
                              dateCreated: DateTime.now().toLocal(),
                              isFromMe: false,
                              hasReactions: true,
                              hasAttachments: true,
                              text: "                                ",
                              handle: Handle(
                                id: Random.secure().nextInt(10000),
                                address: "",
                              ),
                              associatedMessages: [
                                Message(
                                  dateCreated: DateTime.now().toLocal(),
                                  guid: "redacted-mode-demo",
                                  text: "Jane Doe liked a message you sent",
                                  associatedMessageType: "like",
                                  isFromMe: false,
                                ),
                              ],
                              attachments: [
                                Attachment(
                                  guid: "redacted-mode-demo-attachment",
                                  originalROWID: Random.secure().nextInt(10000),
                                  transferName: "assets/images/transparent.png",
                                  mimeType: "image/png",
                                  width: 100,
                                  height: 100,
                                )
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              height = (key.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 250;
                            });
                            confettiController.play();
                          },
                          child: AbsorbPointer(
                            absorbing: true,
                            child: MessageWidget(
                              newerMessage: null,
                              olderMessage: null,
                              isFirstSentMessage: false,
                              showHandle: false,
                              showHero: false,
                              showReplies: false,
                              autoplayEffect: false,
                              message: Message(
                                guid: "redacted-mode-demo-2",
                                dateDelivered2: DateTime.now().toLocal(),
                                dateCreated: DateTime.now().toLocal(),
                                isFromMe: true,
                                hasReactions: false,
                                hasAttachments: false,
                                text: "                  ",
                                expressiveSendStyleId: "com.apple.messages.effect.CKConfettiEffect",
                                handle: Handle(
                                  id: Random.secure().nextInt(10000),
                                  address: "",
                                ),
                              ),
                            ),
                          ),
                        )
                      ]
                  ),
                ],
              ),
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
    );
  }
}
