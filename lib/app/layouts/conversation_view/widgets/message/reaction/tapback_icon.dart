import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// One of the six named tapbacks, filled top to bottom with its iMessage colours.
class TapbackIcon extends StatelessWidget {
  const TapbackIcon(this.type, {super.key});
  final String type;

  static String asset(String type) => 'assets/reactions/$type.svg';

  @override
  Widget build(BuildContext context) => SvgPicture.asset(asset(type));
}
