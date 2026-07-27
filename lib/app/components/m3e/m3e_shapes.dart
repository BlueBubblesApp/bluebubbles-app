import 'package:flutter/material.dart';

/// Material 3 Expressive shape scale.
abstract final class M3EShapes {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;
  static const double xxl = 48;

  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));

  /// Connected-group corners: outer corners of the group are [outer], the seams between
  /// adjacent children are [inner]. A single child is fully [outer].
  static BorderRadius grouped(int index, int count, {double outer = xl, double inner = sm}) {
    if (count <= 0) return BorderRadius.circular(outer);
    final clampedIndex = index.clamp(0, count - 1);

    if (count == 1) {
      return BorderRadius.circular(outer);
    } else if (clampedIndex == 0) {
      return BorderRadius.only(
        topLeft: Radius.circular(outer),
        topRight: Radius.circular(outer),
        bottomLeft: Radius.circular(inner),
        bottomRight: Radius.circular(inner),
      );
    } else if (clampedIndex == count - 1) {
      return BorderRadius.only(
        topLeft: Radius.circular(inner),
        topRight: Radius.circular(inner),
        bottomLeft: Radius.circular(outer),
        bottomRight: Radius.circular(outer),
      );
    } else {
      return BorderRadius.circular(inner);
    }
  }

  /// Connected-group corners along the horizontal axis — same idea as [grouped], for a `Row`.
  static BorderRadius groupedHorizontal(int index, int count, {double outer = xl, double inner = sm}) {
    if (count <= 0) return BorderRadius.circular(outer);
    final clampedIndex = index.clamp(0, count - 1);

    if (count == 1) {
      return BorderRadius.circular(outer);
    } else if (clampedIndex == 0) {
      return BorderRadius.only(
        topLeft: Radius.circular(outer),
        bottomLeft: Radius.circular(outer),
        topRight: Radius.circular(inner),
        bottomRight: Radius.circular(inner),
      );
    } else if (clampedIndex == count - 1) {
      return BorderRadius.only(
        topLeft: Radius.circular(inner),
        bottomLeft: Radius.circular(inner),
        topRight: Radius.circular(outer),
        bottomRight: Radius.circular(outer),
      );
    } else {
      return BorderRadius.circular(inner);
    }
  }
}
