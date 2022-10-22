import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/utils/general_utils.dart';
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
import 'package:bluebubbles/app/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/app/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/core/managers/chat/chat_controller.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';

void sendEffectAction(
    BuildContext context,
    TickerProvider provider,
    String text,
    String subjectText,
    String? threadOriginatorGuid,
    String? chatGuid,
    Future<void> Function({String? effect}) sendMessage,
    ) {
  if (!ss.settings.enablePrivateAPI.value) return;
  String typeSelected = "bubble";
  final bubbleEffects = ["slam", "loud", "gentle", "invisible ink"];
  final screenEffects = ["echo", "spotlight", "balloons", "confetti", "love", "lasers", "fireworks", "celebration"];
  String bubbleSelected = "slam";
  String screenSelected = "echo";
  Message message = Message(
    text: text,
    subject: subjectText,
    dateCreated: DateTime.now(),
    hasAttachments: false,
    threadOriginatorGuid: threadOriginatorGuid,
    isFromMe: true,
    handleId: 0,
  );
  message.generateTempGuid();
  final GlobalKey key = GlobalKey();
  Control animController = Control.stop;
  final FireworkController fireworkController = FireworkController(vsync: provider, windowSize: Size(ns.width(context), context.height));
  final CelebrationController celebrationController = CelebrationController(vsync: provider, windowSize: Size(ns.width(context), context.height));
  final ConfettiController confettiController = ConfettiController(duration: Duration(seconds: 1));
  final BalloonController balloonController = BalloonController(vsync: provider, windowSize: Size(ns.width(context), context.height));
  final LoveController loveController = LoveController(vsync: provider, windowSize: Size(ns.width(context), context.height));
  final SpotlightController spotlightController = SpotlightController(vsync: provider, windowSize: Size(ns.width(context), context.height));
  final LaserController laserController = LaserController(vsync: provider, windowSize: Size(ns.width(context), context.height));
  Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
            opacity: animation,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
                  systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
                  statusBarColor: Colors.transparent, // status bar color
                  statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
                ),
                child: Scaffold(
                  backgroundColor: context.theme.colorScheme.background.withOpacity(0.3),
                  body: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: StatefulBuilder(
                        builder: (BuildContext context, void Function(void Function()) setState) {
                          return Stack(
                            children: [
                              if (screenSelected == "fireworks")
                                Fireworks(controller: fireworkController),
                              if (screenSelected == "celebration")
                                Celebration(controller: celebrationController),
                              if (screenSelected == "balloons")
                                Balloons(controller: balloonController),
                              if (screenSelected == "love")
                                Love(controller: loveController),
                              if (screenSelected == "spotlight")
                                Spotlight(controller: spotlightController),
                              if (screenSelected == "lasers")
                                Laser(controller: laserController),
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
                                          child: Container(
                                            height: 50,
                                            width: ns.width(context) / 2,
                                            child: CupertinoSlidingSegmentedControl<String>(
                                              children: {
                                                "bubble": Text("Bubble"),
                                                "screen": Text("Screen"),
                                              },
                                              groupValue: typeSelected,
                                              thumbColor: CupertinoColors.tertiarySystemFill.lightenOrDarken(20),
                                              backgroundColor: CupertinoColors.tertiarySystemFill,
                                              onValueChanged: (str) {
                                                setState(() {
                                                  typeSelected = str ?? "bubble";
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                        Spacer(),
                                        if (typeSelected == "bubble")
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                                            child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxHeight: 250,
                                                  maxWidth: ns.width(context),
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
                                                            });
                                                            animController = Control.playFromStart;
                                                          },
                                                          child: Container(
                                                            width: ns.width(context) / 3,
                                                            height: 50,
                                                            decoration: BoxDecoration(
                                                              color: CupertinoColors.tertiarySystemFill,
                                                              border:
                                                              Border.fromBorderSide(bubbleSelected == bubbleEffects[index]
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
                                                  maxWidth: ns.width(context),
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
                                                              fireworkController.windowSize = Size(ns.width(context), context.height);
                                                              fireworkController.start();
                                                              await Future.delayed(Duration(seconds: 1));
                                                              fireworkController.stop();
                                                            } else if (screenSelected == "celebration" && !celebrationController.isPlaying) {
                                                              celebrationController.windowSize = Size(ns.width(context), context.height);
                                                              celebrationController.start();
                                                              await Future.delayed(Duration(seconds: 1));
                                                              celebrationController.stop();
                                                            } else if (screenSelected == "balloons" && !balloonController.isPlaying) {
                                                              balloonController.windowSize = Size(ns.width(context), context.height);
                                                              balloonController.start();
                                                              await Future.delayed(Duration(seconds: 1));
                                                              balloonController.stop();
                                                            } else if (screenSelected == "love" && !loveController.isPlaying) {
                                                              if (key.globalPaintBounds(context) != null) {
                                                                loveController.windowSize = Size(ns.width(context), context.height);
                                                                loveController.start(Point((key.globalPaintBounds(context)!.left + key.globalPaintBounds(context)!.right) / 2, (key.globalPaintBounds(context)!.top + key.globalPaintBounds(context)!.bottom) / 2));
                                                                await Future.delayed(Duration(seconds: 1));
                                                                loveController.stop();
                                                              }
                                                            } else if (screenSelected == "spotlight" && !spotlightController.isPlaying) {
                                                              if (key.globalPaintBounds(context) != null) {
                                                                spotlightController.windowSize = Size(ns.width(context), context.height);
                                                                spotlightController.start(key.globalPaintBounds(context)!);
                                                                await Future.delayed(Duration(seconds: 1));
                                                                spotlightController.stop();
                                                              }
                                                            } else if (screenSelected == "lasers" && !laserController.isPlaying) {
                                                              if (key.globalPaintBounds(context) != null) {
                                                                laserController.windowSize = Size(ns.width(context), context.height);
                                                                laserController.start(key.globalPaintBounds(context)!);
                                                                await Future.delayed(Duration(seconds: 1));
                                                                laserController.stop();
                                                              }
                                                            } else if (screenSelected == "confetti") {
                                                              confettiController.play();
                                                            }
                                                          },
                                                          child: Container(
                                                            width: ns.width(context) / 3,
                                                            height: 50,
                                                            decoration: BoxDecoration(
                                                              color: CupertinoColors.tertiarySystemFill,
                                                              border:
                                                              Border.fromBorderSide(screenSelected == screenEffects[index]
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
                                        Spacer(),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Padding(
                                            key: key,
                                            padding: const EdgeInsets.only(right: 5.0),
                                            child: SentMessageHelper.buildMessageWithTail(
                                                context,
                                                message,
                                                true,
                                                false,
                                                message.isBigEmoji(),
                                                MessageWidgetMixin.buildMessageSpansAsync(context, message),
                                                currentChat: ChatController.forGuid(chatGuid),
                                                customColor: Theme.of(context).primaryColor,
                                                effect: stringToMessageEffect[
                                                typeSelected == "bubble" ? bubbleSelected : screenSelected] ??
                                                    MessageEffect.none,
                                                controller: animController, updateController: () {
                                              setState(() {
                                                animController = Control.stop;
                                              });
                                            }),
                                          ),
                                        ),
                                        Spacer(),
                                        TextButton(
                                          child: Text(
                                            typeSelected == "bubble"
                                                ? "Send with $bubbleSelected"
                                                : "Send with $screenSelected",
                                            style: context.theme
                                                .textTheme
                                                .titleLarge!
                                                .apply(color: context.theme.colorScheme.primary),
                                          ),
                                          onPressed: () async {
                                            Navigator.of(context).pop();
                                            await sendMessage(
                                                effect: effectMap[typeSelected == "bubble" ? bubbleSelected : screenSelected]);
                                          },
                                        ),
                                      ])
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                    ),
                  ),
                ),
              ),
            ));
      },
      fullscreenDialog: true,
      opaque: false,
    ),
  );
}