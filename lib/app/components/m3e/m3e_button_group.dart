import 'package:bluebubbles/app/components/m3e/m3e_shapes.dart';
import 'package:bluebubbles/app/components/m3e/m3e_tonal_button.dart';
import 'package:flutter/material.dart';

class M3EButtonGroupItem {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  const M3EButtonGroupItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.onLongPress,
  });
}

/// A row of connected [M3ETonalButton]s — end-caps get [M3EShapes.xl], interior seams get
/// [M3EShapes.sm]. Wraps to a second row when there isn't at least 72dp per item.
class M3EButtonGroup extends StatelessWidget {
  final List<M3EButtonGroupItem> items;

  const M3EButtonGroup({super.key, required this.items});

  static const double _gap = 2;
  static const double _minItemWidth = 72;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxPerRow = (constraints.maxWidth / _minItemWidth).floor().clamp(1, items.length);
        final perRow = items.length > 4 || maxPerRow < items.length
            ? (items.length / ((items.length / maxPerRow).ceil())).ceil()
            : items.length;

        final rows = <List<M3EButtonGroupItem>>[];
        for (int i = 0; i < items.length; i += perRow) {
          rows.add(items.sublist(i, (i + perRow).clamp(0, items.length)));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: _gap),
              Row(
                children: [
                  for (int i = 0; i < rows[r].length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: M3ETonalButton(
                        icon: rows[r][i].icon,
                        label: rows[r][i].label,
                        onPressed: rows[r][i].onPressed,
                        onLongPress: rows[r][i].onLongPress,
                        borderRadius: M3EShapes.groupedHorizontal(i, rows[r].length),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
