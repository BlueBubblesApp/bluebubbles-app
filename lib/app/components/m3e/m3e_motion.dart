import 'package:flutter/material.dart';

class M3EMotionSpec {
  final Duration duration;
  final Curve curve;

  const M3EMotionSpec(this.duration, this.curve);
}

extension M3EMotionX on M3EMotionSpec {
  /// Convenience for driving an [AnimatedContainer] / [AnimatedSwitcher] with this spec.
  Widget container({
    required Widget child,
    Color? color,
    BoxDecoration? decoration,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    double? width,
    double? height,
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      color: decoration == null ? color : null,
      decoration: decoration ?? (borderRadius != null ? BoxDecoration(borderRadius: borderRadius) : null),
      padding: padding,
      width: width,
      height: height,
      child: child,
    );
  }
}

/// Wraps the Material motion tokens from `material/motion.dart` (`Durations.*` / `Easing.*`)
/// into the small set of specs this app's M3E surfaces use.
abstract final class M3EMotion {
  // Spatial — anything that moves or resizes.
  static const spatialFast = M3EMotionSpec(Durations.short4, Easing.emphasizedDecelerate);
  static const spatialDefault = M3EMotionSpec(Durations.medium2, emphasized);
  static const spatialSlow = M3EMotionSpec(Durations.long2, emphasized);

  // Effects — colour, opacity, elevation. No overshoot.
  static const effectsFast = M3EMotionSpec(Durations.short3, Easing.standard);
  static const effectsDefault = M3EMotionSpec(Durations.medium1, Easing.standard);

  // Physics — for AnimationController-driven overshoot (M3E spring model).
  static const SpringDescription springFast = SpringDescription(mass: 1, stiffness: 1400, damping: 46);
  static const SpringDescription springDefault = SpringDescription(mass: 1, stiffness: 700, damping: 40);

  /// The Material 3 "emphasized" easing curve. The Flutter SDK pinned by this repo (3.44.6)
  /// only ships the accelerate/decelerate halves (`Easing.emphasizedAccelerate` /
  /// `Easing.emphasizedDecelerate`) — this joins them at the M3 spec midpoint.
  static const Curve emphasized = ThreePointCubic(
    Offset(0.05, 0),
    Offset(0.133333, 0.06),
    Offset(0.166666, 0.4),
    Offset(0.208333, 0.82),
    Offset(0.25, 1),
  );
}
