import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Thin `fl_chart` line wrapper fed a daily [TimeBucket] series — used for the
/// Overview tab's timeframe-scoped glance chart.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.buckets, this.height = 60.0, this.xLabelBuilder});

  final List<TimeBucket> buckets;
  final double height;

  /// Sparse bottom-axis label for point index `i`; return null to skip.
  /// `titlesData` is omitted entirely (no reserved space) when this is null.
  final String? Function(int index)? xLabelBuilder;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return SizedBox(height: height);

    final spots = <FlSpot>[
      for (var i = 0; i < buckets.length; i++) FlSpot(i.toDouble(), buckets[i].total.toDouble()),
    ];
    final color = context.theme.colorScheme.primary;
    final outline = context.theme.colorScheme.outline;

    return SizedBox(
      // Matches `StatLineChart`'s reservedSize (22.0) — a smaller value here
      // clipped the label text at the bottom edge.
      height: xLabelBuilder == null ? height : height + 22.0,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: xLabelBuilder == null
              ? const FlTitlesData(show: false)
              : FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22.0,
                      // Without this, fl_chart picks its own "nice" interval for
                      // the tick queries, which rarely lands on the indices our
                      // own step-based downsampling below expects — leaving only
                      // the always-included first tick visible. Interval 1 makes
                      // it query every index and defer entirely to xLabelBuilder.
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final label = xLabelBuilder!(value.toInt());
                        if (label == null) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(label, style: TextStyle(fontSize: 10.0, color: outline)),
                        );
                      },
                    ),
                  ),
                ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: color,
              barWidth: 2.0,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }
}
