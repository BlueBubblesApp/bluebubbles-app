import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tuple/tuple.dart';

class LaserController implements Listenable {
  LaserController({
    required this.vsync,
    required this.windowSize,
  });

  final TickerProvider vsync;
  LaserObject? laser;
  List<LaserBeam> beams = [];
  final Random random = Random();
  Size windowSize;

  late Ticker ticker;
  late Point<double> position;
  late double size;
  double globalHue = 42;

  bool isPlaying = false;
  bool requestedToStop = false;
  final List<VoidCallback> listeners = [];

  Duration lastAutoLaunch = Duration.zero;
  Duration autoLaunchDuration = Duration(milliseconds: 500);

  void start(Rect bubbleDimensions) {
    isPlaying = true;
    autoLaunchDuration = Duration(milliseconds: 500);
    lastAutoLaunch = Duration.zero;
    position = Point((bubbleDimensions.left + bubbleDimensions.right) / 2, (bubbleDimensions.top + bubbleDimensions.bottom) / 2);
    ticker = vsync.createTicker(update)..start();
  }

  void stop() {
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

    if (laser == null) {
      beams.addAll(List.generate(12, (index) {
        final width = (random.nextDouble() * 300).clamp(50, 300).toDouble();
        final angle = (random.nextDouble() * 2 * pi).clamp(
            pi / 2 * (index > 8 ? index - 8 : index > 4 ? index - 4 : index), pi / 2 * (index > 8 ? index - 8 : index > 4 ? index - 4 : index) + pi / 2);
        return LaserBeam(
            random: random,
            position: position,
            originalInternalWidth: (random.nextDouble() * 300).clamp(50, 300),
            originalGlobalAngle: pi / 2 * (index > 8 ? index - 8 : index > 4 ? index - 4 : index),
            internalWidth: width,
            globalAngle: angle,
            internalWidthVelocity: width / 50,
            globalAngleVelocity: angle / 50 / ((index > 8 ? index - 8 : index > 4 ? index - 4 : index) + 1),
        );
      }));
    }

    if (autoLaunchDuration != Duration.zero &&
        (elapsedDuration - lastAutoLaunch >= autoLaunchDuration || elapsedDuration == Duration.zero)) {
      lastAutoLaunch = elapsedDuration;
      globalHue += random.nextDouble() * 360;
      globalHue %= 360;
    }

    laser ??= LaserObject(
      random: random,
      position: position,
    );

    laser!.update();
    for (LaserBeam b in beams) {
      b.update();
    }

    if (elapsedDuration.inSeconds > 5 && requestedToStop) {
      ticker.stop();
      ticker.dispose();
      isPlaying = false;
      requestedToStop = false;
      laser = null;
      beams = [];
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

class LaserObject {
  LaserObject({
    required this.random,
    required this.position,
  });

  final Random random;
  final Point<double> position;

  void update() {}
}

class LaserBeam {
  LaserBeam({
    required this.random,
    required this.position,
    required this.originalInternalWidth,
    required this.originalGlobalAngle,
    required this.internalWidth,
    required this.globalAngle,
    required this.internalWidthVelocity,
    required this.globalAngleVelocity,
  }) {
    if (originalGlobalAngle >= 0 && originalGlobalAngle < pi / 2) {
      globalAngleStops = Tuple2(0, pi / 2);
    } else if (originalGlobalAngle >= pi / 2 && originalGlobalAngle < pi) {
      globalAngleStops = Tuple2(pi / 2, pi);
    } else if (originalGlobalAngle >= pi && originalGlobalAngle < 3 * pi / 2) {
      globalAngleStops = Tuple2(pi, 3 * pi / 2);
    } else {
      globalAngleStops = Tuple2(3 * pi / 2, 2 * pi);
    }
    if (internalWidth > originalInternalWidth) {
      internalWidthDirection = Direction.down;
    } else {
      internalWidthDirection = Direction.up;
    }
    if (globalAngle > globalAngleStops.item2) {
      globalAngleDirection = Direction.down;
    } else {
      globalAngleDirection = Direction.up;
    }
  }

  final Random random;
  final Point<double> position;
  final double originalInternalWidth;
  final double originalGlobalAngle;
  late final Tuple2<double, double> globalAngleStops;
  double internalWidth;
  double globalAngle;
  final double internalWidthVelocity;
  final double globalAngleVelocity;
  late Direction internalWidthDirection;
  late Direction globalAngleDirection;

  void update() {
    if (internalWidth > originalInternalWidth || (internalWidthDirection == Direction.down && internalWidth >= 25)) {
      internalWidthDirection = Direction.down;
      internalWidth = internalWidth - internalWidthVelocity;
    }
    if (internalWidth < 25 || (internalWidthDirection == Direction.up && internalWidth <= originalInternalWidth)) {
      internalWidthDirection = Direction.up;
      internalWidth = internalWidth + internalWidthVelocity;
    }
    if (globalAngle >= globalAngleStops.item2 || (globalAngleDirection == Direction.down && globalAngle >= globalAngleStops.item1)) {
      globalAngleDirection = Direction.down;
      globalAngle = globalAngle - globalAngleVelocity;
    }
    if (globalAngle <= globalAngleStops.item1 || (globalAngleDirection == Direction.up && globalAngle <= globalAngleStops.item2)) {
      globalAngleDirection = Direction.up;
      globalAngle = globalAngle + globalAngleVelocity;
    }
  }
}

enum Direction {up, down}