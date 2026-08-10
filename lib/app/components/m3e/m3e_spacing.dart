/// M3 Expressive spacing scale — padding, gaps and insets.
///
/// Separate from [M3EShapes] on purpose. Corner radii and spacing are
/// independent axes of the design system that merely happen to share several
/// values today; feeding a radius token to an `EdgeInsets` couples them, so
/// retuning a corner silently reflows every layout that borrowed it.
abstract final class M3ESpacing {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
