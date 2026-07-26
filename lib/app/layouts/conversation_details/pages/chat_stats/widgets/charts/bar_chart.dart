import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One rod within a [BarGroupSpec]. Multiple entries render as a grouped
/// cluster (e.g. "you" vs. "group median" in the response-time histogram).
class BarValueSpec {
  final double value;
  final Color color;
  const BarValueSpec({required this.value, required this.color});
}

class BarGroupSpec {
  final String label;
  final List<BarValueSpec> bars;
  const BarGroupSpec({required this.label, required this.bars});
}

/// Thin `fl_chart` bar-chart wrapper with theming applied once — no tab
/// configures raw `fl_chart` objects directly. Used for hour-of-day,
/// day-of-week, response-time histograms, and opener/ender paired bars.
class StatBarChart extends StatelessWidget {
  const StatBarChart({
    super.key,
    required this.groups,
    this.height = 160.0,
    this.maxY,
    this.barWidth = 14.0,
    this.labelEvery = 1,
    this.showYAxis = false,
    this.rotateLabels = false,
  });

  final List<BarGroupSpec> groups;
  final double height;
  final double? maxY;
  final double barWidth;

  /// Only render a bottom-axis label every Nth group (e.g. every 3rd hour).
  final int labelEvery;

  /// Show tick labels along the left axis.
  final bool showYAxis;

  /// Angles bottom-axis labels ~45° so long or numerous labels (e.g. words)
  /// don't overlap the way they would sitting flat. Widens the reserved
  /// bottom space to fit the rotated text.
  final bool rotateLabels;

  @override
  Widget build(BuildContext context) {
    final outline = context.theme.colorScheme.outline;
    final tallest = groups.expand((g) => g.bars).fold<double>(0, (a, b) => b.value > a ? b.value : a);
    final effectiveMax = maxY ?? (tallest <= 0 ? 1.0 : tallest * 1.15);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: effectiveMax,
          minY: 0,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                rod.toY.round().toString(),
                TextStyle(
                  color: (rod.color ?? Colors.white).computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: showYAxis
                  ? SideTitles(
                      showTitles: true,
                      reservedSize: 28.0,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || (value != 0 && value % meta.appliedInterval != 0)) {
                          return const SizedBox.shrink();
                        }
                        return Text(value.round().toString(), style: TextStyle(fontSize: 10.0, color: outline));
                      },
                    )
                  : const SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: rotateLabels ? 46.0 : 22.0,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= groups.length) return const SizedBox.shrink();
                  if (labelEvery > 1 && idx % labelEvery != 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    angle: rotateLabels ? -math.pi / 4 : 0.0,
                    fitInside: rotateLabels
                        ? SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 2.0)
                        : const SideTitleFitInsideData(enabled: false, distanceFromEdge: 0, parentAxisSize: 0, axisPosition: 0),
                    child: Text(groups[idx].label, style: TextStyle(fontSize: 10.0, color: outline)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < groups.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4.0,
                barRods: [
                  for (final bar in groups[i].bars)
                    BarChartRodData(
                      toY: bar.value,
                      color: bar.color,
                      width: barWidth,
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
