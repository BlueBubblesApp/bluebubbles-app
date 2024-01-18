import 'dart:math' as math;
import 'dart:ui' as ui;

abstract class Color {
  const Color();

  // All colors should have a conversion path to linear sRGB
  LinearSrgb toLinearSrgb();
}

class LinearSrgb extends Color {
  final double r;
  final double g;
  final double b;

  const LinearSrgb(this.r, this.g, this.b);

  @override
  LinearSrgb toLinearSrgb() => this;

  Srgb toSrgb() {
    return Srgb._(
      _oetf(r),
      _oetf(g),
      _oetf(b),
    );
  }

  Oklab toOklab() {
    final double l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
    final double m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
    final double s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

    final double l2 = root(l, 3);
    final double m2 = root(m, 3);
    final double s2 = root(s, 3);

    return Oklab(
      0.2104542553 * l2 + 0.7936177850 * m2 - 0.0040720468 * s2,
      1.9779984951 * l2 - 2.4285922050 * m2 + 0.4505937099 * s2,
      0.0259040371 * l2 + 0.7827717662 * m2 - 0.8086757660 * s2,
    );
  }

  CieXyz toCieXyz() {
    return CieXyz(
      0.4124564 * r + 0.3575761 * g + 0.1804375 * b,
      0.2126729 * r + 0.7151522 * g + 0.0721750 * b,
      0.0193339 * r + 0.1191920 * g + 0.9503041 * b,
    );
  }

  static double _oetf(double x) {
    if (x >= 0.0031308) {
      return 1.055 * math.pow(x, 1.0 / 2.4) - 0.055;
    } else {
      return 12.92 * x;
    }
  }

  // Electro-optical transfer function
  // Inverse transform to linear sRGB
  static double _eotf(double x) {
    if (x >= 0.04045) {
      return math.pow((x + 0.055) / 1.055, 2.4) as double;
    } else {
      return x / 12.92;
    }
  }
}

class Srgb extends Color {
  final double r;
  final double g;
  final double b;

  Srgb(int r, int g, int b)
      : this._(
      r.toDouble() / 255.0, g.toDouble() / 255.0, b.toDouble() / 255.0);
  const Srgb._(this.r, this.g, this.b);

  // Convenient constructors for quantized values
  Srgb.fromColor(ui.Color color) : this(color.red, color.green, color.blue);

  @override
  LinearSrgb toLinearSrgb() => LinearSrgb(
    LinearSrgb._eotf(r),
    LinearSrgb._eotf(g),
    LinearSrgb._eotf(b),
  );

  int quantize8() {
    return ui.Color.fromRGBO(_quantize8(r), _quantize8(g), _quantize8(b), 1)
        .value;
  }

  static int _quantize8(double n) => (n * 255.0).toInt().clamp(0, 255);
}

abstract class Lab {
  final double l;
  final double a;
  final double b;

  const Lab(this.l, this.a, this.b);

  List<double> toLch() {
    final double hDeg = toDegrees(math.atan2(b, a));

    return [
      l,
      math.sqrt(a * a + b * b),
      if (hDeg < 0) hDeg + 360 else hDeg,
    ];
  }
}

abstract class Lch {
  final double l;
  final double c;
  final double h;

  const Lch(this.l, this.c, this.h);

  List<double> toLab() {
    final double hRad = toRadians(h);

    return [
      l,
      c * math.cos(hRad),
      c * math.sin(hRad),
    ];
  }
}

class Oklab extends Lab implements Color {
  const Oklab(super.l, super.a, super.b);

  @override
  LinearSrgb toLinearSrgb() {
    final double l2 = this.l + 0.3963377774 * a + 0.2158037573 * b;
    final double m2 = this.l - 0.1055613458 * a - 0.0638541728 * b;
    final double s2 = this.l - 0.0894841775 * a - 1.2914855480 * b;

    final double l = l2 * l2 * l2;
    final double m = m2 * m2 * m2;
    final double s = s2 * s2 * s2;

    return LinearSrgb(
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    );
  }

  Oklch toOklch() {
    final List<double> values = toLch();
    return Oklch(values[0], values[1], values[2]);
  }
}

class Oklch extends Lch implements Color {
  const Oklch(super.l, super.c, [super.h = 0.0]);

  @override
  LinearSrgb toLinearSrgb() => toOklab().toLinearSrgb();

  Oklab toOklab() {
    final List<double> values = toLab();
    return Oklab(values[0], values[1], values[2]);
  }
}

class CieXyz extends Color {
  final double x;
  final double y;
  final double z;

  const CieXyz(this.x, this.y, this.z);

  @override
  LinearSrgb toLinearSrgb() {
    return LinearSrgb(
      3.2404542 * x + -1.5371385 * y + -0.4985314 * z,
      -0.9692660 * x + 1.8760108 * y + 0.0415560 * z,
      0.0556434 * x + -0.2040259 * y + 1.0572252 * z,
    );
  }

  static double _f(double x) {
    if (x > 216.0 / 24389.0) {
      return root(x, 3);
    } else {
      return x / (108.0 / 841.0) + 4.0 / 29.0;
    }
  }

  CieLab toCieLab() {
    return CieLab(
      116.0 * _f(y / illuminantsD65.y) - 16.0,
      500.0 * (_f(x / illuminantsD65.x) - _f(y / illuminantsD65.y)),
      200.0 * (_f(y / illuminantsD65.y) - _f(z / illuminantsD65.z)),
    );
  }
}

class CieLab extends Lab {
  const CieLab(super.l, super.a, super.b);

  CieXyz toCieXyz() {
    final double lp = (l + 16.0) / 116.0;

    return CieXyz(
      illuminantsD65.x * _fInv(lp + (a / 500.0)),
      illuminantsD65.y * _fInv(lp),
      illuminantsD65.z * _fInv(lp - (b / 200.0)),
    );
  }

  CieLch toCieLch() {
    final List<double> values = toLch();
    return CieLch(values[0], values[1], values[2]);
  }

  static double _fInv(double x) {
    if (x > 6.0 / 29.0) {
      return x * x * x;
    } else {
      return (108.0 / 841.0) * (x - 4.0 / 29.0);
    }
  }
}

class CieLch extends Lch {
  const CieLch(super.l, super.c, super.h);

  CieLab toCieLab() {
    final List<double> values = toLab();
    return CieLab(values[0], values[1], values[2]);
  }
}

double toRadians(double degrees) {
  return degrees * math.pi / 180;
}

double toDegrees(double radians) {
  return radians * 180 / math.pi;
}

double root(num base, num factor) =>
    (math.pow(base, 1 / factor) * 1000000000).round() / 1000000000;

const CieXyz illuminantsD65 = CieXyz(0.95047, 1.0, 0.108883);