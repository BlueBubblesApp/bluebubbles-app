import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/layouts/animations/fireworks_classes.dart';
import 'package:flutter/scheduler.dart';

class CelebrationController extends FireworkController {
  CelebrationController({
    required TickerProvider vsync,
    required Size windowSize,
  }) : super(vsync: vsync, windowSize: windowSize);

  @override
  void start() {
    isPlaying = true;
    autoLaunchDuration = Duration(milliseconds: 100);
    lastAutoLaunch = Duration.zero;
    ticker = vsync.createTicker(update)..start();
  }

  @override
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

  @override
  void dispose() {
    listeners.clear();
    ticker.dispose();
  }

  @override
  void update(Duration elapsedDuration) {
    if (windowSize == Size.zero) {
      // We need to wait until we have the size.
      return;
    }

    if (particles.isEmpty && !requestedToStop) {
      for (int x = 0; x < 10; x++) {
        _createCelebration();
      }
    }

    for (final particle in particles) {
      particle.update();
    }

    particles.removeWhere((element) => element.alpha <= 0);
    if (particles.isEmpty && requestedToStop) {
      ticker.stop();
      ticker.dispose();
      isPlaying = false;
      requestedToStop = false;
      hasCreatedParticles = false;
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

  void _createCelebration() {
    for (var i = 0; i < explosionParticleCount; i++) {
      hasCreatedParticles = true;
      particles.add(FireworkParticle(
        random: random,
        position: Point(windowSize.width, 0),
        hueBaseValue: 28,
        saturation: 0.5,
        isCelebration: true,
        size: 10,
      ));
    }
  }
}