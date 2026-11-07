import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// One of the six named tapbacks, filled top to bottom with its iMessage colours.
class TapbackIcon extends StatelessWidget {
  const TapbackIcon(this.type, {super.key});
  final String type;

  // Fixed like Messages' own, not theme colours: they read on both bubble colours
  static const Map<String, List<Color>> _gradients = {
    "love": [Color(0xFFFF8AC0), Color(0xFFF0479A)],
    "like": [Color(0xFFFFD84A), Color(0xFFF39A1E)],
    "dislike": [Color(0xFFFFD84A), Color(0xFFF39A1E)],
    "laugh": [Color(0xFF8EDCFF), Color(0xFF2E9CF0)],
    "emphasize": [Color(0xFFFF6B5E), Color(0xFFE83A6E)],
    "question": [Color(0xFFD2B6FF), Color(0xFF9B6BEA)],
  };

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _gradients[type] ?? const [Colors.grey, Colors.grey],
      ).createShader(bounds),
      child: SvgPicture.asset('assets/reactions/$type-black.svg'),
    );
  }
}
