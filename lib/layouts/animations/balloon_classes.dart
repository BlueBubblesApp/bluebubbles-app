import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class BalloonController implements Listenable {
  BalloonController({
    required this.vsync,
    required this.windowSize,
  });

  final TickerProvider vsync;
  final List<BalloonObject> balloons = [];
  final Random random = Random();
  Size windowSize;

  late Ticker ticker;

  bool isPlaying = false;
  bool requestedToStop = false;
  final List<VoidCallback> listeners = [];

  Duration lastAutoLaunch = Duration.zero;
  Duration autoLaunchDuration = Duration(milliseconds: 100);

  void start() {
    isPlaying = true;
    autoLaunchDuration = Duration(milliseconds: 100);
    lastAutoLaunch = Duration.zero;
    ticker = vsync.createTicker(update)..start();
  }

  void stop() {
    autoLaunchDuration = Duration.zero;
    requestedToStop = true;
  }

  @override
  void addListener(listener) {
    assert(!listeners.contains(listener));

    listeners.add(listener);
  }

  @override
  void removeListener(listener) {
    assert(listeners.contains(listener));

    listeners.remove(listener);
  }

  void dispose() {
    listeners.clear();
    ticker.dispose();
  }

  void update(Duration elapsedDuration) {
    if (windowSize == Size.zero) {
      // We need to wait until we have the size.
      return;
    }

    if (autoLaunchDuration != Duration.zero &&
        (elapsedDuration - lastAutoLaunch >= autoLaunchDuration || elapsedDuration == Duration.zero)) {
      lastAutoLaunch = elapsedDuration;
      balloons.add(BalloonObject(
        random: random,
        position: Point(windowSize.width, windowSize.height + 100),
        color: primaries[random.nextInt(primaries.length)],
        radius: (random.nextDouble() * 100).clamp(40, 100),
        angle: pi / 2 - random.nextDouble() * pi / 6,
      ));
    }

    for (final balloon in balloons) {
      balloon.update();
    }

    balloons.removeWhere((element) {
      return element.position.y < -100 || element.position.x < -100;
    });
    if (balloons.isEmpty && requestedToStop) {
      ticker.stop();
      ticker.dispose();
      isPlaying = false;
      requestedToStop = false;
    }
    // Notify listeners.
    // The copy of the list and the condition prevent
    // ConcurrentModificationError's, in case a listener removes itself
    // or another listener.
    // See https://stackoverflow.com/q/62417999/6509751.
    for (final listener in List.of(listeners)) {
      if (!listeners.contains(listener)) continue;
      listener.call();
    }
  }
}

class BalloonObject {
  BalloonObject({
    required this.random,
    required this.position,
    required this.color,
    required this.radius,
    required this.angle
  });

  final Random random;
  Point<double> position;
  final Color color;
  final double radius;
  final double angle;

  double velocity = 8;

  void update() {
    position = Point(position.x - velocity * cos(angle), position.y - velocity * sin(angle));
  }
}

const List<MaterialColor> primaries = <MaterialColor>[
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.blue,
  Colors.lightBlue,
  Colors.green,
  Colors.lightGreen,
  Colors.orange,
  Colors.yellow,
];