import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChartSeries {
  final String label;
  final Color color;
  final List<double> values;
  const ChartSeries({required this.label, required this.color, required this.values});
}

enum LineChartMode {
  /// Independent lines, each drawn and filled on its own (1:1 volume: sent vs. received).
  lines,

  /// Cumulative stacked area — series are summed bottom-to-top (group volume, group balance drift).
  stackedArea,

  /// A single series split into two fill colors above/below [referenceY]
  /// (1:1 balance drift around the 50% line).
  referenceSplit,
}

/// Thin `fl_chart` line/area wrapper with theming applied once — no tab
/// configures raw `fl_chart` objects directly. See `bar_chart.dart` for the
/// bar-chart counterpart.
class StatLineChart extends StatelessWidget {
  const StatLineChart({
    super.key,
    required this.series,
    this.mode = LineChartMode.lines,
    this.height = 180.0,
    this.minY,
    this.maxY,
    this.referenceY,
    this.secondaryColor,
    this.xLabelBuilder,
    this.showYAxis = false,
  });

  final List<ChartSeries> series;
  final LineChartMode mode;
  final double height;
  final double? minY;
  final double? maxY;

  /// Dashed reference line (e.g. 50%, or 100/N% for a group).
  final double? referenceY;

  /// [LineChartMode.referenceSplit] only — fill color for the region below
  /// [referenceY] (the "them" side of the line).
  final Color? secondaryColor;

  /// Sparse bottom-axis label for point index `i`; return null to skip.
  final String? Function(int index)? xLabelBuilder;

  /// Show tick labels along the left axis.
  final bool showYAxis;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty || series.first.values.isEmpty) return SizedBox(height: height);
    final outline = context.theme.colorScheme.outline;
    final pointCount = series.first.values.length;

    double effectiveMin = minY ?? 0;
    double effectiveMax = maxY ??
        (mode == LineChartMode.stackedArea
            ? _stackedMax(series)
            : series.expand((s) => s.values).fold<double>(0, (a, b) => b > a ? b : a) * 1.15);
    if (effectiveMax <= effectiveMin) effectiveMax = effectiveMin + 1;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: effectiveMin,
          maxY: effectiveMax,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: showYAxis
                  ? SideTitles(
                      showTitles: true,
                      reservedSize: 32.0,
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
                showTitles: xLabelBuilder != null,
                reservedSize: 22.0,
                // See Sparkline for why this must be 1 rather than left to
                // fl_chart's auto interval — otherwise only the first tick shows.
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final label = xLabelBuilder?.call(value.toInt());
                  if (label == null) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(label, style: TextStyle(fontSize: 10.0, color: outline)),
                  );
                },
              ),
            ),
          ),
          extraLinesData: referenceY == null
              ? const ExtraLinesData()
              : ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: referenceY!,
                    color: outline.withValues(alpha: 0.6),
                    strokeWidth: 1.0,
                    dashArray: const [5, 4],
                  ),
                ]),
          lineBarsData: switch (mode) {
            LineChartMode.lines => [for (final s in series) _plainLine(s, pointCount)],
            LineChartMode.stackedArea => _stackedLines(series, pointCount),
            LineChartMode.referenceSplit =>
              _referenceSplitLines(series.first, pointCount, referenceY ?? 0, secondaryColor ?? outline),
          },
        ),
      ),
    );
  }

  LineChartBarData _plainLine(ChartSeries s, int pointCount) {
    return LineChartBarData(
      spots: [for (var i = 0; i < pointCount; i++) FlSpot(i.toDouble(), s.values[i])],
      isCurved: true,
      curveSmoothness: 0.2,
      color: s.color,
      barWidth: 2.0,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: s.color.withValues(alpha: 0.12)),
    );
  }

  /// Cumulative-sum hack for a stacked area: draw the tallest cumulative
  /// series first, then progressively smaller cumulative series on top of it
  /// so each later (smaller) layer visually occludes the previous one down to
  /// its own height — `fl_chart` has no native stacked-line primitive.
  List<LineChartBarData> _stackedLines(List<ChartSeries> series, int pointCount) {
    final cumulative = List<List<double>>.generate(series.length, (_) => List.filled(pointCount, 0.0));
    for (var i = 0; i < pointCount; i++) {
      double running = 0;
      for (var s = 0; s < series.length; s++) {
        running += series[s].values[i];
        cumulative[s][i] = running;
      }
    }
    return [
      for (var s = series.length - 1; s >= 0; s--)
        LineChartBarData(
          spots: [for (var i = 0; i < pointCount; i++) FlSpot(i.toDouble(), cumulative[s][i])],
          isCurved: true,
          curveSmoothness: 0.15,
          color: series[s].color,
          barWidth: 1.0,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: series[s].color.withValues(alpha: 0.85)),
        ),
    ];
  }

  List<LineChartBarData> _referenceSplitLines(
    ChartSeries s,
    int pointCount,
    double referenceY,
    Color secondaryColor,
  ) {
    final spots = [for (var i = 0; i < pointCount; i++) FlSpot(i.toDouble(), s.values[i])];
    return [
      LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.15,
        color: s.color,
        barWidth: 2.0,
        dotData: const FlDotData(show: false),
        aboveBarData: BarAreaData(
          show: true,
          applyCutOffY: true,
          cutOffY: referenceY,
          color: s.color.withValues(alpha: 0.22),
        ),
        belowBarData: BarAreaData(
          show: true,
          applyCutOffY: true,
          cutOffY: referenceY,
          color: secondaryColor.withValues(alpha: 0.22),
        ),
      ),
    ];
  }

  double _stackedMax(List<ChartSeries> series) {
    double max = 0;
    for (var i = 0; i < series.first.values.length; i++) {
      double sum = 0;
      for (final s in series) {
        sum += s.values[i];
      }
      if (sum > max) max = sum;
    }
    return max * 1.1;
  }
}
