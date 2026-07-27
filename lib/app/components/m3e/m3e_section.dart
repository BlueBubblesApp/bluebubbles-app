import 'package:bluebubbles/app/components/m3e/m3e_shapes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum M3ESectionTone { neutral, error }

/// The expressive replacement for `SettingsSection`.
///
/// The group fill is always derived from [backgroundColor] (the `tileColor` callers already
/// compute, which carries window-effect alpha and any per-chat surface override) — never from
/// `colorScheme.surfaceContainer*` directly, since that would break Mica/acrylic and per-chat
/// themes. Any tonal step within the group is a lighten/darken of that same colour.
class M3ESection extends StatelessWidget {
  final List<Widget> children;
  final Color backgroundColor;
  final M3ESectionTone tone;
  final EdgeInsets margin;
  final double gap;

  const M3ESection({
    super.key,
    required this.children,
    required this.backgroundColor,
    this.tone = M3ESectionTone.neutral,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.gap = 2,
  });

  @override
  Widget build(BuildContext context) {
    // Conditionally-hidden rows still show up as SizedBox.shrink() — strip them before
    // indexing or they corrupt the grouped-corner sequence.
    final visibleChildren = children.where((child) => child is! SizedBox || child.width != 0 || child.height != 0);
    final displayedChildren = visibleChildren.toList(growable: false);

    if (displayedChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    final fill = tone == M3ESectionTone.error
        ? Color.lerp(backgroundColor, context.theme.colorScheme.errorContainer, 0.35)!
        : backgroundColor;

    return Padding(
      padding: margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < displayedChildren.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            ClipRRect(
              borderRadius: M3EShapes.grouped(i, displayedChildren.length),
              child: Container(
                color: fill,
                child: displayedChildren[i],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
