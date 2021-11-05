import 'dart:math';

import 'package:bluebubbles/layouts/animations/balloon_classes.dart';
import 'package:bluebubbles/layouts/animations/balloon_rendering.dart';
import 'package:bluebubbles/layouts/animations/celebration_class.dart';
import 'package:bluebubbles/layouts/animations/celebration_rendering.dart';
import 'package:bluebubbles/layouts/animations/fireworks_classes.dart';
import 'package:bluebubbles/layouts/animations/fireworks_rendering.dart';
import 'package:bluebubbles/layouts/animations/laser_classes.dart';
import 'package:bluebubbles/layouts/animations/laser_rendering.dart';
import 'package:bluebubbles/layouts/animations/love_classes.dart';
import 'package:bluebubbles/layouts/animations/love_rendering.dart';
import 'package:bluebubbles/layouts/animations/spotlight_classes.dart';
import 'package:bluebubbles/layouts/animations/spotlight_rendering.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

class ScreenEffectsWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _ScreenEffectsWidgetState();
  }
}

class _ScreenEffectsWidgetState extends State<ScreenEffectsWidget> with TickerProviderStateMixin {
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

    fireworkController = FireworkController(vsync: this);
    celebrationController = CelebrationController(vsync: this);
    confettiController = ConfettiController(duration: Duration(seconds: 1));
    balloonController = BalloonController(vsync: this);
    loveController = LoveController(vsync: this);
    spotlightController = SpotlightController(vsync: this);
    laserController = LaserController(vsync: this);

    EventDispatcher().stream.listen((Map<String, dynamic> event) async {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'play-effect' && mounted) {
        setState(() {
          screenSelected = event['data']['type'];
        });
        final rect = event['data']['size'];
        if (screenSelected == "fireworks" && !fireworkController.isPlaying) {
          fireworkController.start();
          await Future.delayed(Duration(seconds: 1));
          fireworkController.stop();
        } else if (screenSelected == "celebration" && !celebrationController.isPlaying) {
          celebrationController.start();
          await Future.delayed(Duration(seconds: 1));
          celebrationController.stop();
        } else if (screenSelected == "balloons" && !balloonController.isPlaying) {
          balloonController.start();
          await Future.delayed(Duration(seconds: 1));
          balloonController.stop();
        } else if (screenSelected == "love" && !loveController.isPlaying) {
          if (rect != null) {
            loveController.start(Point((rect!.left + rect!.right) / 2, (rect!.top + rect!.bottom) / 2));
            await Future.delayed(Duration(seconds: 1));
            loveController.stop();
          }
        } else if (screenSelected == "spotlight" && !spotlightController.isPlaying) {
          if (rect != null) {
            spotlightController.start(rect!);
            await Future.delayed(Duration(seconds: 1));
            spotlightController.stop();
          }
        } else if (screenSelected == "lasers" && !laserController.isPlaying) {
          if (rect != null) {
            laserController.start(rect!);
            await Future.delayed(Duration(seconds: 1));
            laserController.stop();
          }
        } else if (screenSelected == "confetti") {
          confettiController.play();
        }
      }
    });
  }


  @override
  Widget build(BuildContext context) {
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
        ]
    );
  }
}