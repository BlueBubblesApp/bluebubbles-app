import 'package:bluebubbles/app/components/charts/charts.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_controller.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_segment_row.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Results view: headline stat tiles, a donut of segment shares, and
/// per-segment rows carrying the select-to-delete affordance (the actual
/// delete flow lands in Task 08).
class StorageResultsSection extends StatelessWidget with StorageAnalyzerHelpersMixin {
  const StorageResultsSection({super.key, required this.controller, required this.result});

  final StorageAnalyzerController controller;
  final StorageAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final largest = result.segments.isEmpty
        ? null
        : result.segments.reduce((a, b) => a.bytes >= b.bytes ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatTileGrid(
            tiles: [
              StatTile(
                value: formatBytes(result.totalBytes),
                label: "Reclaimable",
                icon: context.iOS ? CupertinoIcons.chart_pie : Icons.pie_chart_outline,
                backgroundColor: context.tileColor,
                shadow: true,
              ),
              StatTile(
                value: "${result.totalFiles}",
                label: "Files",
                icon: context.iOS ? CupertinoIcons.doc_on_doc : Icons.description_outlined,
                backgroundColor: context.tileColor,
                shadow: true,
              ),
              if (largest != null)
                StatTile(
                  value: StorageAnalyzerHelpersMixin.segmentConfig[largest.type]!.label,
                  label: "Largest Segment",
                  caption: formatBytes(largest.bytes),
                  icon: context.iOS
                      ? StorageAnalyzerHelpersMixin.segmentConfig[largest.type]!.iosIcon
                      : StorageAnalyzerHelpersMixin.segmentConfig[largest.type]!.materialIcon,
                  backgroundColor: context.tileColor,
                  shadow: true,
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (result.totalBytes > 0)
            DonutChart(
              slices: [
                for (final segment in result.segments)
                  if (segment.bytes > 0)
                    DonutSlice(
                      label: StorageAnalyzerHelpersMixin.segmentConfig[segment.type]!.label,
                      value: segment.bytes.toDouble(),
                      color: colorFor(context, segment.type),
                    ),
              ],
              centerLabel: formatBytes(result.totalBytes),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "No attachments match this filter.",
                  style: context.theme.textTheme.bodyMedium?.copyWith(color: context.theme.colorScheme.outline),
                ),
              ),
            ),
          const SizedBox(height: 28),
          if (result.segments.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: context.tileColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: context.tileColor.darkenAmount(0.1).withValues(alpha: 0.25),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Obx(() => Column(
                    children: [
                      for (var i = 0; i < result.segments.length; i++) ...[
                        StorageSegmentRow(
                          segment: result.segments[i],
                          totalBytes: result.totalBytes,
                          selected: controller.selectedSegments.contains(result.segments[i].type),
                          onTap: () => controller.toggleSegment(result.segments[i].type),
                        ),
                        if (i != result.segments.length - 1)
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 16,
                            endIndent: 16,
                            color: context.theme.colorScheme.outline.withValues(alpha: 0.5),
                          ),
                      ],
                    ],
                  )),
            ),
          if (!result.orphanScanValid)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                "Orphaned files aren't shown while a chat or age filter is active.",
                style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ),
          // Extra clearance so the floating "Free up" action (StorageFreeUpFab,
          // hosted by the panel's SettingsScaffold) never sits on top of the
          // last row when a selection is active.
          const SizedBox(height: 72),
        ],
      ),
    );
  }
}
