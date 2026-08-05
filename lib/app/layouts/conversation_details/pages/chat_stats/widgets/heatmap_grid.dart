import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

/// Reusable N×M grid of colored cells — serves both the weekday×hour heatmap
/// and the calendar heatmap. No charting package; a `Column`/`Row` of
/// `Container`s is all either visual needs.
///
/// Uses a 5-level discrete intensity ramp (`sqrt` scaling) rather than a
/// continuous `value / maxValue` lerp — message activity is heavily skewed,
/// and a linear ramp flattens every cell but the outlier to near-invisible.
class HeatmapGrid extends StatefulWidget {
  const HeatmapGrid({
    super.key,
    required this.values, // [row][col]
    required this.maxValue,
    this.rowLabels,
    this.colLabels, // null entries occupy width without a label
    this.cellSize = 14.0,
    this.cellSpacing = 3.0,
    this.cellLabel,
    this.onCellTap,
    this.scrollToEnd = false,
    this.showLegend = true,
  });

  final List<List<int>> values;
  final int maxValue;
  final List<String>? rowLabels;
  final List<String?>? colLabels;
  final double cellSize;
  final double cellSpacing;

  /// Tooltip/semantics text for cell (row, col). Defaults to "`<n>` messages".
  final String Function(int row, int col, int value)? cellLabel;
  final void Function(int row, int col)? onCellTap;

  /// Opens the horizontal scroll at the most recent end (calendar heatmap).
  final bool scrollToEnd;
  final bool showLegend;

  @override
  State<HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<HeatmapGrid> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.scrollToEnd) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) _controller.jumpTo(_controller.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _levelFor(int value) {
    if (value <= 0 || widget.maxValue <= 0) return 0;
    final ratio = min(1.0, value / widget.maxValue);
    return (sqrt(ratio) * 5).ceil().clamp(1, 5);
  }

  Color _colorFor(BuildContext context, int level) {
    final empty = context.theme.colorScheme.surfaceContainerHighest;
    final full = context.theme.colorScheme.primary;
    // Level 0 stays a fixed, low-alpha shade so it reads clearly against the
    // lowest non-zero level in both light and dark mode.
    if (level == 0) return empty.withValues(alpha: 0.55);
    return Color.lerp(empty, full, 0.32 + (level / 5.0) * 0.68)!;
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.values.length;
    final cols = rows == 0 ? 0 : widget.values.first.length;
    final rowHeight = widget.cellSize + widget.cellSpacing;
    final outline = context.theme.colorScheme.outline;

    Widget cell(int r, int c) {
      final value = widget.values[r][c];
      final level = _levelFor(value);
      final label = widget.cellLabel?.call(r, c, value) ?? "$value message${value == 1 ? '' : 's'}";
      return Padding(
        padding: EdgeInsets.only(right: widget.cellSpacing, bottom: widget.cellSpacing),
        child: Tooltip(
          message: label,
          child: Semantics(
            label: label,
            child: GestureDetector(
              onTap: widget.onCellTap == null ? null : () => widget.onCellTap!(r, c),
              child: Container(
                width: widget.cellSize,
                height: widget.cellSize,
                decoration: BoxDecoration(color: _colorFor(context, level), borderRadius: BorderRadius.circular(3.0)),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.rowLabels != null)
              Padding(
                padding: EdgeInsets.only(top: widget.colLabels != null ? rowHeight : 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final label in widget.rowLabels!)
                      SizedBox(
                        height: rowHeight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(label, style: context.theme.textTheme.labelSmall?.copyWith(color: outline)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.colLabels != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final label in widget.colLabels!)
                            SizedBox(
                              width: widget.cellSize + widget.cellSpacing,
                              height: rowHeight,
                              child: label == null
                                  ? null
                                  : Text(label, style: context.theme.textTheme.labelSmall?.copyWith(color: outline, fontSize: 9.0)),
                            ),
                        ],
                      ),
                    for (var r = 0; r < rows; r++) Row(mainAxisSize: MainAxisSize.min, children: [for (var c = 0; c < cols; c++) cell(r, c)]),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (widget.showLegend) ...[
          const SizedBox(height: 8.0),
          _Legend(colorFor: (level) => _colorFor(context, level)),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colorFor});
  final Color Function(int level) colorFor;

  @override
  Widget build(BuildContext context) {
    final outline = context.theme.colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Less", style: context.theme.textTheme.labelSmall?.copyWith(color: outline)),
        const SizedBox(width: 4.0),
        for (var level = 0; level <= 5; level++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 10.0,
              height: 10.0,
              decoration: BoxDecoration(color: colorFor(level), borderRadius: BorderRadius.circular(2.0)),
            ),
          ),
        const SizedBox(width: 4.0),
        Text("More", style: context.theme.textTheme.labelSmall?.copyWith(color: outline)),
      ],
    );
  }
}
