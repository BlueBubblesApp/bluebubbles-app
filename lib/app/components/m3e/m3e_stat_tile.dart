import 'package:bluebubbles/app/components/m3e/m3e_shapes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Expressive KPI tile — a colorful tonal container (`primaryContainer` /
/// `secondaryContainer` / `tertiaryContainer`, never `surfaceContainer*`)
/// with `M3EShapes.xl` corners and no elevation. M3 Expressive favors tonal
/// fill and shape over shadow, unlike the neutral, shadowed `StatTile` used
/// by the iOS skin and chat-stats.
class M3EStatTile extends StatelessWidget {
  const M3EStatTile({
    super.key,
    required this.value,
    required this.label,
    this.caption,
    this.icon,
    this.containerColor,
    this.onContainerColor,
  });

  final String value;
  final String label;
  final String? caption;
  final IconData? icon;

  /// Defaults to `colorScheme.primaryContainer`. Pass a different container
  /// role (e.g. `tertiaryContainer`) to vary color across a row of tiles —
  /// the expressive multi-tonal look, not a single repeated accent.
  final Color? containerColor;
  final Color? onContainerColor;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final fill = containerColor ?? cs.primaryContainer;
    final onFill = onContainerColor ?? cs.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(M3EShapes.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: onFill),
            const SizedBox(height: 8.0),
          ],
          Text(
            value,
            style: context.theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: onFill),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2.0),
          Text(
            label,
            style: context.theme.textTheme.bodySmall?.copyWith(color: onFill.withValues(alpha: 0.8)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...[
            const SizedBox(height: 2.0),
            Text(
              caption!,
              style: context.theme.textTheme.labelSmall?.copyWith(color: onFill.withValues(alpha: 0.8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
