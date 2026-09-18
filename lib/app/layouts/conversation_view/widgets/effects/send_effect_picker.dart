import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/bubble_effects.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/animations/balloon_classes.dart';
import 'package:bluebubbles/app/animations/balloon_rendering.dart';
import 'package:bluebubbles/app/animations/celebration_class.dart';
import 'package:bluebubbles/app/animations/celebration_rendering.dart';
import 'package:bluebubbles/app/animations/fireworks_classes.dart';
import 'package:bluebubbles/app/animations/fireworks_rendering.dart';
import 'package:bluebubbles/app/animations/laser_classes.dart';
import 'package:bluebubbles/app/animations/laser_rendering.dart';
import 'package:bluebubbles/app/animations/love_classes.dart';
import 'package:bluebubbles/app/animations/love_rendering.dart';
import 'package:bluebubbles/app/animations/spotlight_classes.dart';
import 'package:bluebubbles/app/animations/spotlight_rendering.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/window_effect.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';

void sendEffectAction(
  BuildContext context,
  TickerProvider provider,
  String text,
  String subjectText,
  String? threadOriginatorGuid,
  int? part,
  String? chatGuid,
  Future<void> Function({String? effect}) sendMessage,
  List<Mentionable> mentionables,
) {
  if (!SettingsSvc.settings.enablePrivateAPI.value) return;
  String typeSelected = "bubble";
  final bubbleEffects = ["slam", "loud", "gentle", "invisible ink"];
  final screenEffects = ["echo", "spotlight", "balloons", "confetti", "love", "lasers", "fireworks", "celebration"];
  String bubbleSelected = "slam";
  String screenSelected = "echo";
  final textSplit = MentionTextEditingController.splitText(text);
  bool flag = false;
  final newText = [];
  if (textSplit.length > 1) {
    for (String word in textSplit) {
      if (word == MentionTextEditingController.escapingChar) flag = !flag;
      int? index = flag ? int.tryParse(word) : null;
      if (index != null) {
        final mention = mentionables[index];
        newText.add(mention);
        continue;
      }
      if (word == MentionTextEditingController.escapingChar) {
        continue;
      }
      newText.add(word.replaceAll(MentionTextEditingController.escapingChar, ""));
    }
    text = newText.join("");
  }
  int currentPos = 0;
  final message = Message(
    text: text,
    subject: subjectText,
    threadOriginatorGuid: threadOriginatorGuid,
    threadOriginatorPart: "${part ?? 0}:0:0",
    expressiveSendStyleId: effectMap["slam"],
    dateCreated: DateTime.now(),
    hasAttachments: false,
    isFromMe: true,
    handleId: 0,
    hasDdResults: true,
    attributedBody: [
      if (textSplit.length > 1)
        AttributedBody(
          string: text,
          runs: newText.whereType<Mentionable>().isEmpty
              ? []
              : newText.map((e) {
                  if (e is Mentionable) {
                    final run = Run(
                        range: [currentPos, e.toString().length],
                        attributes: Attributes(
                          mention: e.address,
                          messagePart: 0,
                        ));
                    currentPos += e.toString().length;
                    return run;
                  } else {
                    final run = Run(
                      range: [currentPos, e.length],
                      attributes: Attributes(
                        messagePart: 0,
                      ),
                    );
                    currentPos += e.toString().length;
                    return run;
                  }
                }).toList(),
        ),
    ],
  );
  message.generateTempGuid();
  final previewState = MessageState(message);
  final GlobalKey key = GlobalKey();
  Control animController = Control.stop;
  final FireworkController fireworkController =
      FireworkController(vsync: provider, windowSize: Size(NavigationSvc.width(context), context.height));
  final CelebrationController celebrationController =
      CelebrationController(vsync: provider, windowSize: Size(NavigationSvc.width(context), context.height));
  final ConfettiController confettiController = ConfettiController(duration: const Duration(seconds: 1));
  final BalloonController balloonController =
      BalloonController(vsync: provider, windowSize: Size(NavigationSvc.width(context), context.height));
  final LoveController loveController =
      LoveController(vsync: provider, windowSize: Size(NavigationSvc.width(context), context.height));
  final SpotlightController spotlightController =
      SpotlightController(vsync: provider, windowSize: Size(NavigationSvc.width(context), context.height));
  final LaserController laserController =
      LaserController(vsync: provider, windowSize: Size(NavigationSvc.width(context), context.height));
  // Capture the conversation's theme before pushing the route — if adaptive
  // theming is active, context.theme is already the per-chat theme.
  final capturedTheme = context.theme;
  final capturedIsM3 = ThemeSvc.isMaterialYouActive(context);
  final capturedBubbleExt = capturedTheme.extensions[BubbleColors] as BubbleColors?;
  Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: BBScaffold(
              backgroundColor: kIsDesktop && SettingsSvc.settings.windowEffect.value != WindowEffect.disabled
                  ? capturedTheme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9)
                  : Colors.transparent,
              safeAreaLeft: false,
              safeAreaRight: false,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: kIsDesktop && SettingsSvc.settings.windowEffect.value != WindowEffect.disabled ? 0 : 30,
                        sigmaY:
                            kIsDesktop && SettingsSvc.settings.windowEffect.value != WindowEffect.disabled ? 0 : 30),
                    child: Container(
                      color: capturedTheme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                  ),
                  StatefulBuilder(builder: (BuildContext context, void Function(void Function()) setState) {
                    return Stack(
                      children: [
                        if (screenSelected == "fireworks") Fireworks(controller: fireworkController),
                        if (screenSelected == "celebration") Celebration(controller: celebrationController),
                        if (screenSelected == "balloons") Balloons(controller: balloonController),
                        if (screenSelected == "love") Love(controller: loveController),
                        if (screenSelected == "spotlight") Spotlight(controller: spotlightController),
                        if (screenSelected == "lasers") Laser(controller: laserController),
                        if (screenSelected == "confetti")
                          Align(
                            alignment: Alignment.topCenter,
                            child: ConfettiWidget(
                              confettiController: confettiController,
                              blastDirection: pi / 2,
                              blastDirectionality: BlastDirectionality.explosive,
                              emissionFrequency: 0.35,
                            ),
                          ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(
                                child: Column(children: [
                              Text(
                                "Send with effect",
                                style: context.theme.textTheme.headlineSmall!,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20.0),
                                child: SizedBox(
                                  height: 50,
                                  width: NavigationSvc.width(context) / 2,
                                  child: CupertinoSlidingSegmentedControl<String>(
                                    children: {
                                      "bubble": const Text("Bubble"),
                                      "screen": const Text("Screen"),
                                    },
                                    groupValue: typeSelected,
                                    thumbColor: CupertinoColors.tertiarySystemFill.oppositeLightenOrDarken(20),
                                    backgroundColor: CupertinoColors.tertiarySystemFill,
                                    onValueChanged: (str) {
                                      setState(() {
                                        typeSelected = str ?? "bubble";
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (typeSelected == "bubble")
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                                  child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: 250,
                                        maxWidth: NavigationSvc.width(context),
                                      ),
                                      child: SingleChildScrollView(
                                        child: Wrap(
                                          alignment: WrapAlignment.center,
                                          children: List.generate(bubbleEffects.length, (index) {
                                            return Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    bubbleSelected = bubbleEffects[index];
                                                    message.expressiveSendStyleId = effectMap[bubbleSelected];
                                                    previewState.triggerBubbleEffect(0);
                                                    if (bubbleSelected == "gentle") {
                                                      animController = Control.playFromStart;
                                                    }
                                                  });
                                                },
                                                child: Container(
                                                  width: NavigationSvc.width(context) / 3,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    color: CupertinoColors.tertiarySystemFill,
                                                    border: Border.fromBorderSide(bubbleSelected == bubbleEffects[index]
                                                        ? BorderSide(
                                                            color: context.theme.colorScheme.primary,
                                                            width: 1.5,
                                                            style: BorderStyle.solid,
                                                          )
                                                        : BorderSide.none),
                                                    borderRadius: BorderRadius.circular(5),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      bubbleEffects[index].toUpperCase(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                      )),
                                ),
                              if (typeSelected == "screen")
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                                  child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: 350,
                                        maxWidth: NavigationSvc.width(context),
                                      ),
                                      child: SingleChildScrollView(
                                        child: Wrap(
                                          alignment: WrapAlignment.center,
                                          children: List.generate(screenEffects.length, (index) {
                                            return Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: GestureDetector(
                                                onTap: () async {
                                                  setState(() {
                                                    screenSelected = screenEffects[index];
                                                  });
                                                  if (screenSelected == "fireworks" && !fireworkController.isPlaying) {
                                                    fireworkController.windowSize =
                                                        Size(NavigationSvc.width(context), context.height);
                                                    fireworkController.start();
                                                    await Future.delayed(const Duration(seconds: 1));
                                                    fireworkController.stop();
                                                  } else if (screenSelected == "celebration" &&
                                                      !celebrationController.isPlaying) {
                                                    celebrationController.windowSize =
                                                        Size(NavigationSvc.width(context), context.height);
                                                    celebrationController.start();
                                                    await Future.delayed(const Duration(seconds: 1));
                                                    celebrationController.stop();
                                                  } else if (screenSelected == "balloons" &&
                                                      !balloonController.isPlaying) {
                                                    balloonController.windowSize =
                                                        Size(NavigationSvc.width(context), context.height);
                                                    balloonController.start();
                                                    await Future.delayed(const Duration(seconds: 1));
                                                    balloonController.stop();
                                                  } else if (screenSelected == "love" && !loveController.isPlaying) {
                                                    if (key.globalPaintBounds(context) != null) {
                                                      loveController.windowSize =
                                                          Size(NavigationSvc.width(context), context.height);
                                                      loveController.start(Point(
                                                          (key.globalPaintBounds(context)!.left +
                                                                  key.globalPaintBounds(context)!.right) /
                                                              2,
                                                          (key.globalPaintBounds(context)!.top +
                                                                  key.globalPaintBounds(context)!.bottom) /
                                                              2));
                                                      await Future.delayed(const Duration(seconds: 1));
                                                      loveController.stop();
                                                    }
                                                  } else if (screenSelected == "spotlight" &&
                                                      !spotlightController.isPlaying) {
                                                    if (key.globalPaintBounds(context) != null) {
                                                      spotlightController.windowSize =
                                                          Size(NavigationSvc.width(context), context.height);
                                                      spotlightController.start(key.globalPaintBounds(context)!);
                                                      await Future.delayed(const Duration(seconds: 1));
                                                      spotlightController.stop();
                                                    }
                                                  } else if (screenSelected == "lasers" && !laserController.isPlaying) {
                                                    if (key.globalPaintBounds(context) != null) {
                                                      laserController.windowSize =
                                                          Size(NavigationSvc.width(context), context.height);
                                                      laserController.start(key.globalPaintBounds(context)!);
                                                      await Future.delayed(const Duration(seconds: 1));
                                                      laserController.stop();
                                                    }
                                                  } else if (screenSelected == "confetti") {
                                                    confettiController.play();
                                                  }
                                                },
                                                child: Container(
                                                  width: NavigationSvc.width(context) / 3,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    color: CupertinoColors.tertiarySystemFill,
                                                    border: Border.fromBorderSide(screenSelected == screenEffects[index]
                                                        ? BorderSide(
                                                            color: context.theme.colorScheme.primary,
                                                            width: 1.5,
                                                            style: BorderStyle.solid,
                                                          )
                                                        : BorderSide.none),
                                                    borderRadius: BorderRadius.circular(5),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      screenEffects[index].toUpperCase(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                      )),
                                ),
                              const Spacer(),
                              if (text.isNotEmpty || subjectText.isNotEmpty)
                                Theme(
                                  data: capturedTheme.copyWith(
                                    // in case some components still use legacy theming
                                    primaryColor:
                                        capturedBubbleExt?.iMessageBubbleColor ?? capturedTheme.colorScheme.primary,
                                    colorScheme: capturedTheme.colorScheme.copyWith(
                                      primary:
                                          capturedBubbleExt?.iMessageBubbleColor ?? capturedTheme.colorScheme.primary,
                                      onPrimary: capturedBubbleExt?.oniMessageBubbleColor ??
                                          capturedTheme.colorScheme.onPrimary,
                                      surface: capturedIsM3 ? null : capturedBubbleExt?.receivedBubbleColor,
                                      onSurface: capturedIsM3 ? null : capturedBubbleExt?.onReceivedBubbleColor,
                                    ),
                                  ),
                                  child: Builder(builder: (context) {
                                    return Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          key: key,
                                          padding: const EdgeInsets.only(right: 5.0),
                                          child: BubbleEffects(
                                            messageState: previewState,
                                            globalKey: key,
                                            part: 0,
                                            // Unsent stand-in message — animate
                                            // it, but never persist it as played.
                                            isPreview: true,
                                              showTail: true,
                                              child: ClipPath(
                                                clipper: TailClipper(
                                                  isFromMe: true,
                                                  showTail: true,
                                                  connectLower: false,
                                                  connectUpper: false,
                                                ),
                                                child: Container(
                                                  constraints: BoxConstraints(
                                                    maxWidth: NavigationSvc.width(context) *
                                                            MessageState.maxBubbleSizeFactor -
                                                        40,
                                                    minHeight: 40,
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15)
                                                      .add(const EdgeInsets.only(right: 10)),
                                                  color: context.theme.colorScheme.primary,
                                                  child: CustomAnimationBuilder<Movie>(
                                                    control: animController,
                                                    tween: MovieTween()
                                                      ..scene(
                                                              begin: Duration.zero,
                                                              duration: const Duration(milliseconds: 1),
                                                              curve: Curves.easeInOut)
                                                          .tween("size", 1.0.tweenTo(1.0))
                                                      ..scene(
                                                              begin: const Duration(milliseconds: 1),
                                                              duration: const Duration(milliseconds: 500),
                                                              curve: Curves.easeInOut)
                                                          .tween("size", 0.0.tweenTo(0.5))
                                                      ..scene(
                                                              begin: const Duration(milliseconds: 1000),
                                                              duration: const Duration(milliseconds: 800),
                                                              curve: Curves.easeInOut)
                                                          .tween("size", 0.5.tweenTo(1.0)),
                                                    duration: const Duration(milliseconds: 1800),
                                                    animationStatusListener: (status) {
                                                      if (status == AnimationStatus.completed) {
                                                        setState(() {
                                                          animController = Control.stop;
                                                        });
                                                      }
                                                    },
                                                    builder: (context, anim, child) {
                                                      final value1 = anim.get("size");
                                                      return Transform.scale(
                                                        scale: value1,
                                                        alignment: Alignment.center,
                                                        child: RichText(
                                                          text: TextSpan(
                                                            children: buildMessageSpans(
                                                              context,
                                                              MessagePart(
                                                                  part: 0,
                                                                  text: message.text,
                                                                  mentions: message.attributedBody.isEmpty
                                                                      ? []
                                                                      : message.attributedBody.first.runs
                                                                          .where((element) => element.hasMention)
                                                                          .map((e) => Mention(
                                                                                  mentionedAddress: "",
                                                                                  range: [
                                                                                    e.range.first,
                                                                                    e.range.first + e.range.last
                                                                                  ]))
                                                                          .toList()),
                                                              message,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ));
                                  }),
                                ),
                              const Spacer(),
                              TextButton(
                                child: Text(
                                  typeSelected == "bubble" ? "Send with $bubbleSelected" : "Send with $screenSelected",
                                  style: context.theme.textTheme.titleLarge!
                                      .apply(color: context.theme.colorScheme.primary),
                                ),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await sendMessage(
                                      effect: effectMap[typeSelected == "bubble" ? bubbleSelected : screenSelected]);
                                },
                              ),
                            ])),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
      fullscreenDialog: true,
      opaque: false,
    ),
  );
}
