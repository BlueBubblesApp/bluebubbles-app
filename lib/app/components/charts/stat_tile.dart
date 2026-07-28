import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A single KPI card: a big value, a label, and an optional caption/icon.
/// Used in a responsive grid — 2 columns on mobile, 3–4 on desktop/tablet.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.caption,
    this.icon,
    this.backgroundColor,
    this.shadow = false,
  });

  final String value;
  final String label;
  final String? caption;
  final IconData? icon;

  /// Defaults to a translucent tonal fill. Pass `context.tileColor` for pages
  /// (e.g. Storage Analyzer) that want the same grouped-list tile background
  /// used elsewhere in Settings — plain `surfaceContainerHighest` reads as
  /// nearly invisible against the Cupertino skin's background.
  final Color? backgroundColor;

  /// Adds the same subtle card shadow the iMessage Stats page's stat cards
  /// use. Off by default so existing (flat) chat-stats usages are unaffected.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final fill = backgroundColor ?? context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: context.theme.colorScheme.primary),
          const SizedBox(height: 6.0),
        ],
        Text(
          value,
          style: context.theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.outline),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (caption != null) ...[
          const SizedBox(height: 2.0),
          Text(
            caption!,
            style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.outline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: content,
    );
  }
}

/// Responsive grid of KPI tiles — 2 columns on mobile, 3–4 on desktop/tablet.
/// Takes any `Widget` (not just [StatTile]) so the Material/Samsung expressive
/// skins can lay out `M3EStatTile`s in the same grid.
class StatTileGrid extends StatelessWidget {
  const StatTileGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10.0,
            mainAxisSpacing: 10.0,
            childAspectRatio: 1.5,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) => tiles[index],
        );
      },
    );
  }
}
