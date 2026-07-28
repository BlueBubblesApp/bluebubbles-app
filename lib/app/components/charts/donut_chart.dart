import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DonutSlice {
  final String label;
  final double value;
  final Color color;
  const DonutSlice({required this.label, required this.value, required this.color});

  @override
  bool operator ==(Object other) =>
      other is DonutSlice && other.label == label && other.value == value && other.color == color;

  @override
  int get hashCode => Object.hash(label, value, color);
}

/// Thin `fl_chart` donut wrapper — used for "who texts first" / "who ends
/// conversations". Two-way for 1:1, N-way for groups; same widget either way.
///
/// Tapping a legend entry toggles that slice out of the chart (and out of the
/// percentage math for the remaining slices) without discarding it — tap
/// again to bring it back. Purely a display-side filter; callers don't need
/// to know about it.
class DonutChart extends StatefulWidget {
  const DonutChart({super.key, required this.slices, this.size = 140.0, this.centerLabel});

  final List<DonutSlice> slices;
  final double size;
  final String? centerLabel;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  final Set<int> _hiddenIndices = {};

  @override
  void didUpdateWidget(DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New data — stale hidden-index selections may no longer even correspond
    // to the same slices, so drop the filter rather than carry it forward.
    if (!listEquals(oldWidget.slices, widget.slices)) _hiddenIndices.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slices.isEmpty) return SizedBox(height: widget.size);

    final visibleTotal = <double>[
      for (var i = 0; i < widget.slices.length; i++)
        if (!_hiddenIndices.contains(i)) widget.slices[i].value,
    ].fold<double>(0, (a, b) => a + b);

    return Row(
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (visibleTotal > 0)
                PieChart(
                  PieChartData(
                    sectionsSpace: 2.0,
                    centerSpaceRadius: widget.size * 0.3,
                    sections: [
                      for (var i = 0; i < widget.slices.length; i++)
                        if (!_hiddenIndices.contains(i))
                          PieChartSectionData(
                            value: widget.slices[i].value,
                            color: widget.slices[i].color,
                            showTitle: false,
                            radius: widget.size * 0.2,
                          ),
                    ],
                  ),
                ),
              if (widget.centerLabel != null)
                Text(widget.centerLabel!, style: context.theme.textTheme.labelMedium, textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(width: 16.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.slices.length; i++) _legendRow(context, i, visibleTotal),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow(BuildContext context, int index, double visibleTotal) {
    final slice = widget.slices[index];
    final isHidden = _hiddenIndices.contains(index);
    final pct = !isHidden && visibleTotal > 0 ? (slice.value / visibleTotal * 100).round() : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (isHidden) {
          _hiddenIndices.remove(index);
        } else {
          _hiddenIndices.add(index);
        }
      }),
      child: Opacity(
        opacity: isHidden ? 0.4 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            children: [
              Container(width: 10.0, height: 10.0, decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle)),
              const SizedBox(width: 6.0),
              Expanded(
                child: Text(
                  slice.label,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    decoration: isHidden ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                pct == null ? "—" : "$pct%",
                style: context.theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
