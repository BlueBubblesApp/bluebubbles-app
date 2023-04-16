import 'dart:math';

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
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ScreenEffectsWidget extends StatefulWidget {
  const ScreenEffectsWidget();

  @override
  State<StatefulWidget> createState() {
    return _ScreenEffectsWidgetState();
  }
}

class _ScreenEffectsWidgetState extends OptimizedState<ScreenEffectsWidget> with TickerProviderStateMixin {
  late final FireworkController fireworkController;
  late final CelebrationController celebrationController;
  late final ConfettiController confettiController;
  late final BalloonController balloonController;
  late final LoveController loveController;
  late final SpotlightController spotlightController;
  late final LaserController laserController;
  String screenSelected = "";

  @override
  void initState() {
    super.initState();

    updateObx(() {
      fireworkController = FireworkController(vsync: this, windowSize: Size(ns.width(context), context.height));
      celebrationController = CelebrationController(vsync: this, windowSize: Size(ns.width(context), context.height));
      confettiController = ConfettiController(duration: const Duration(seconds: 1));
      balloonController = BalloonController(vsync: this, windowSize: Size(ns.width(context), context.height));
      loveController = LoveController(vsync: this, windowSize: Size(ns.width(context), context.height));
      spotlightController = SpotlightController(vsync: this, windowSize: Size(ns.width(context), context.height));
      laserController = LaserController(vsync: this, windowSize: Size(ns.width(context), context.height));
    });

    eventDispatcher.stream.listen((event) async {
      if (event.item1 == 'play-effect' && mounted && screenSelected.isEmpty) {
        setState(() {
          screenSelected = event.item2['type'];
        });
        final rect = event.item2['size'];
        if (screenSelected == "fireworks" && !fireworkController.isPlaying) {
          fireworkController.windowSize = Size(ns.width(context), context.height);
          fireworkController.start();
          await Future.delayed(const Duration(seconds: 1));
          fireworkController.stop(onStop: () {
            setState(() {
              screenSelected = "";
            });
          });
        } else if (screenSelected == "celebration" && !celebrationController.isPlaying) {
          celebrationController.windowSize = Size(ns.width(context), context.height);
          celebrationController.start();
          await Future.delayed(const Duration(seconds: 1));
          celebrationController.stop(onStop: () {
            setState(() {
              screenSelected = "";
            });
          });
        } else if (screenSelected == "balloons" && !balloonController.isPlaying) {
          balloonController.windowSize = Size(ns.width(context), context.height);
          balloonController.start();
          await Future.delayed(const Duration(seconds: 1));
          balloonController.stop(onStop: () {
            setState(() {
              screenSelected = "";
            });
          });
        } else if (screenSelected == "love" && !loveController.isPlaying) {
          if (rect != null) {
            loveController.windowSize = Size(ns.width(context), context.height);
            loveController.start(Point((rect!.left + rect!.right) / 2, (rect!.top + rect!.bottom) / 2));
            await Future.delayed(const Duration(seconds: 1));
            loveController.stop(onStop: () {
              setState(() {
                screenSelected = "";
              });
            });
          }
        } else if (screenSelected == "spotlight" && !spotlightController.isPlaying) {
          if (rect != null) {
            spotlightController.windowSize = Size(ns.width(context), context.height);
            spotlightController.start(rect!);
            await Future.delayed(const Duration(seconds: 1));
            spotlightController.stop(onStop: () {
              setState(() {
                screenSelected = "";
              });
            });
          }
        } else if (screenSelected == "lasers" && !laserController.isPlaying) {
          if (rect != null) {
            laserController.windowSize = Size(ns.width(context), context.height);
            laserController.start(rect!);
            await Future.delayed(const Duration(seconds: 1));
            laserController.stop(onStop: () {
              setState(() {
                screenSelected = "";
              });
            });
          }
        } else if (screenSelected == "confetti") {
          confettiController.play();
          await Future.delayed(const Duration(seconds: 1));
          screenSelected = "";
        }
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: screenSelected == "fireworks"
          || screenSelected == "celebration"
          || screenSelected == "spotlight"
          || screenSelected == "lasers"
        ? Colors.black : Colors.transparent,
      child: screenSelected.isEmpty ? null : Stack(
        children: [
          Fireworks(controller: fireworkController),
          Celebration(controller: celebrationController),
          Balloons(controller: balloonController),
          Love(controller: loveController),
          Spotlight(controller: spotlightController),
          Laser(controller: laserController),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.35,
            ),
          ),
        ]
      ),
    );
  }
}