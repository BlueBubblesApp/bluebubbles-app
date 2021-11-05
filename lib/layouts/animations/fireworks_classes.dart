import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Class managing a whole firework show.
///
/// [addListener] can be used to get notified about updates (triggered by the
/// ticker created by the given [vsync]).
///
/// It spawns [FireworkRocket]s and creates [FireworkParticle] explosions.
class FireworkController implements Listenable {
  FireworkController({
    required this.vsync,
    required this.windowSize,
  });

  final TickerProvider vsync;
  final List<FireworkRocket> rockets = [];
  final List<FireworkParticle> particles = [];
  final Random random = Random();
  Size windowSize;
  double globalHue = 42;

  late Ticker ticker;

  bool hasCreatedParticles = false;
  bool isPlaying = false;
  bool requestedToStop = false;
  final List<VoidCallback> listeners = [];

  Duration lastAutoLaunch = Duration.zero;
  Duration autoLaunchDuration = Duration(milliseconds: 100);
  double particleSize = 3;
  double get _rocketSize => max(0, particleSize - 1);
  int explosionParticleCount = 96;

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

    globalHue += random.nextDouble() * 360;
    globalHue %= 360;

    if (autoLaunchDuration != Duration.zero &&
        (elapsedDuration - lastAutoLaunch >= autoLaunchDuration || elapsedDuration == Duration.zero)) {
      lastAutoLaunch = elapsedDuration;
      rockets.add(FireworkRocket(
        random: random,
        start: Point(
          32 + random.nextDouble() * (windowSize.width - 32) - 32,
          windowSize.height * 1.2,
        ),
        target: Point(
          8 + random.nextDouble() * (windowSize.width - 8) - 8,
          8 + random.nextDouble() * windowSize.height * 4 / 7,
        ),
        hue: globalHue,
        size: _rocketSize,
      ));
    }

    for (final rocket in rockets) {
      rocket.update();
    }
    for (final particle in particles) {
      particle.update();
    }

    rockets.removeWhere((element) {
      final targetReached = element.distanceTraveled >= element.targetDistance;
      if (!targetReached) return false;

      // We want to create an explosion when a rocket reaches its target.
      _createExplosion(element);
      return targetReached;
    });
    particles.removeWhere((element) => element.alpha <= 0);
    if (particles.isEmpty && requestedToStop && hasCreatedParticles) {
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

  void _createExplosion(FireworkRocket rocket) {
    for (var i = 0; i < explosionParticleCount; i++) {
      hasCreatedParticles = true;
      particles.add(FireworkParticle(
        random: random,
        position: rocket.position,
        hueBaseValue: rocket.hue,
        size: particleSize,
      ));
    }
  }
}

/// Abstract class for firework objects that store information about their
/// trail.
///
/// This also acts as an abstract base class for all firework objects in
/// general, i.e. the [update] function.
abstract class FireworkObjectWithTrail {
  FireworkObjectWithTrail({
    required this.random,
    required this.trailCount,
    required this.position,
    required this.size,
  })   : assert(size >= 0),
        trailPoints = [
          // Fill the trail with the starting position initially.
          for (var i = 0; i < trailCount; i++) position,
        ];

  /// [Random] instance used for generating random numbers in the firework
  /// object.
  final Random random;

  /// The current position of the object.
  Point<double> position;

  /// How many trailing points should be stored.
  final int trailCount;

  final List<Point<double>> trailPoints;

  /// The particle size in logical pixels.
  ///
  /// This size will be used for the stroke width.
  final double size;

  /// Updates the state of the object.
  @mustCallSuper
  void update() {
    trailPoints.removeLast();
    trailPoints.insert(0, position);
  }
}

/// Firework particle that is part of an explosion.
///
/// Inspired by https://codepen.io/whqet/pen/Auzch.
class FireworkParticle extends FireworkObjectWithTrail {
  FireworkParticle({
    required Random random,
    required Point<double> position,
    required double hueBaseValue,
    this.saturation,
    bool isCelebration = false,
    required double size,
  })   : angle = random.nextDouble() * 2 * pi,
        velocity = random.nextDouble() * (isCelebration ? 50 : 12) + 1,
        hue = hueBaseValue + (isCelebration ? 0 : - 50 + random.nextDouble() * 100),
        brightness = .5 + random.nextDouble() * .3,
        alphaDecay = random.nextDouble() * .007 + .013,
        super(
        trailCount: isCelebration ? 2 : size.toInt() * 2,
        position: position,
        random: random,
        size: isCelebration ? random.nextDouble() * 10 : size,
      );

  final double angle;

  double velocity;
  final double friction = .96;
  final double gravity = 2.35;

  final double hue;
  final double? saturation;
  final double brightness;

  double alpha = 1;
  final double alphaDecay;

  @override
  void update() {
    super.update();

    velocity *= friction;

    position += Point(
      cos(angle) * velocity,
      sin(angle) * velocity + gravity,
    );

    alpha -= alphaDecay;
  }
}

/// The part of a firework that handles the launch path.
///
/// The actual explosion is handled using [FireworkParticle]s.
///
/// Inspired by https://codepen.io/whqet/pen/Auzch.
class FireworkRocket extends FireworkObjectWithTrail {
  FireworkRocket({
    required Random random,
    required this.start,
    required this.target,
    required this.hue,
    required double size,
  })   : targetDistance = target.distanceTo(start),
        angle = atan2(target.y - start.y, target.x - start.x),
        brightness = .5 + random.nextDouble() * .2,
        super(
        trailCount: 2,
        position: start,
        random: random,
        size: size,
      );

  final Point<double> start;
  final Point<double> target;

  final double angle;
  final double targetDistance;
  double distanceTraveled = 0;

  double velocity = 1;
  final double acceleration = 1.025;

  final double hue;
  final double brightness;

  @override
  void update() {
    super.update();

    velocity *= acceleration;

    // In this case, using Offset would actually be nicer because it is counter
    // intuitive that the velocity vector is a point..
    final vp = Point(cos(angle) * velocity, sin(angle) * velocity);
    distanceTraveled = (position + vp).distanceTo(start);

    if (distanceTraveled < targetDistance) {
      position += vp;
    }
  }
}