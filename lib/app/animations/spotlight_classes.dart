import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class SpotlightController implements Listenable {
  SpotlightController({
    required this.vsync,
    required this.windowSize,
  });

  final TickerProvider vsync;
  SpotlightObject? spotlight;
  final Random random = Random();
  Size windowSize;

  late Ticker ticker;
  late Point<double> position;
  late double size;

  bool isPlaying = false;
  bool requestedToStop = false;
  final List<VoidCallback> listeners = [];

  Duration lastAutoLaunch = Duration.zero;
  Duration autoLaunchDuration = Duration(milliseconds: 100);

  void start(Rect bubbleDimensions) {
    isPlaying = true;
    autoLaunchDuration = Duration(milliseconds: 100);
    lastAutoLaunch = Duration.zero;
    position = Point((bubbleDimensions.left + bubbleDimensions.right) / 2, (bubbleDimensions.top + bubbleDimensions.bottom) / 2);
    size = max(bubbleDimensions.width, bubbleDimensions.height) + 50;
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

    spotlight ??= SpotlightObject(
      random: random,
      originalPosition: position,
      position: position,
      size: size,
    );

    spotlight!.update(elapsedDuration);

    if (spotlight!.stop < 0 && requestedToStop) {
      ticker.stop();
      ticker.dispose();
      isPlaying = false;
      requestedToStop = false;
      spotlight = null;
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

class SpotlightObject {
  SpotlightObject({
    required this.random,
    required this.originalPosition,
    required this.position,
    required this.size,
  });

  final Random random;
  final Point<double> originalPosition;
  Point<double> position;
  final double size;
  double stop = 1;

  void update(Duration elapsed) {
    if (elapsed.inSeconds < 3) {
      position = Point(originalPosition.x + (random.nextDouble() - .5), originalPosition.y + (random.nextDouble() - .5));
    } else {
      stop = stop - 0.05;
    }
  }
}