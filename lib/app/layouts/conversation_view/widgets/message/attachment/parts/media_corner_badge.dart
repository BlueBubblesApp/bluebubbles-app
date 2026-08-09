import 'package:flutter/material.dart';

/// Small rounded tag overlaid on a corner of a media preview — same visual
/// treatment as the GIF/LIVE badges in `image_viewer.dart`. Must be used
/// inside a [Stack].
class MediaCornerBadge extends StatelessWidget {
  final IconData? icon;
  final String label;

  /// Anchors the badge to the top-left instead of the top-right.
  final bool alignLeft;

  const MediaCornerBadge({
    super.key,
    this.icon,
    required this.label,
    this.alignLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: alignLeft ? null : 8,
      left: alignLeft ? 8 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
