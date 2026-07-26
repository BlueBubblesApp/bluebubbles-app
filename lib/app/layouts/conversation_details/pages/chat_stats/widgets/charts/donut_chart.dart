import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DonutSlice {
  final String label;
  final double value;
  final Color color;
  const DonutSlice({required this.label, required this.value, required this.color});
}

/// Thin `fl_chart` donut wrapper — used for "who texts first" / "who ends
/// conversations". Two-way for 1:1, N-way for groups; same widget either way.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.size = 140.0, this.centerLabel});

  final List<DonutSlice> slices;
  final double size;
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (a, b) => a + b.value);
    if (total <= 0) return SizedBox(height: size);

    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2.0,
                  centerSpaceRadius: size * 0.3,
                  sections: [
                    for (final slice in slices)
                      PieChartSectionData(
                        value: slice.value,
                        color: slice.color,
                        showTitle: false,
                        radius: size * 0.2,
                      ),
                  ],
                ),
              ),
              if (centerLabel != null)
                Text(centerLabel!, style: context.theme.textTheme.labelMedium, textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(width: 16.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final slice in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    children: [
                      Container(width: 10.0, height: 10.0, decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle)),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          slice.label,
                          style: context.theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "${(slice.value / total * 100).round()}%",
                        style: context.theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
