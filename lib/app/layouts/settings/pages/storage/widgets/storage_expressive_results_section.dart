import 'package:bluebubbles/app/components/charts/charts.dart';
import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_controller.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Expressive results view for the Material/Samsung skins — headline stat
/// tiles, a donut of segment shares, and `M3ESection`-grouped segment rows
/// carrying the select-to-delete affordance. Same data as the iOS
/// `StorageResultsSection`; M3E chrome only.
class StorageExpressiveResultsSection extends StatelessWidget with StorageAnalyzerHelpersMixin {
  const StorageExpressiveResultsSection({super.key, required this.controller, required this.result});

  final StorageAnalyzerController controller;
  final StorageAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final visibleSegments = result.segments.where((s) => s.fileCount > 0).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatTileGrid(
            tiles: [
              M3EStatTile(
                value: formatBytes(result.totalBytes),
                label: "Reclaimable",
                icon: Icons.pie_chart_outline,
                containerColor: context.theme.colorScheme.primaryContainer,
                onContainerColor: context.theme.colorScheme.onPrimaryContainer,
              ),
              M3EStatTile(
                value: "${result.totalFiles}",
                label: "Files",
                icon: Icons.description_outlined,
                containerColor: context.theme.colorScheme.tertiaryContainer,
                onContainerColor: context.theme.colorScheme.onTertiaryContainer,
              ),
            ],
          ),
          if (result.totalBytes > 0) ...[
            const SizedBox(height: 32),
            DonutChart(
              slices: [
                for (final segment in visibleSegments)
                  DonutSlice(
                    label: StorageAnalyzerHelpersMixin.segmentConfig[segment.type]!.label,
                    value: segment.bytes.toDouble(),
                    color: colorFor(context, segment.type),
                  ),
              ],
              centerLabel: formatBytes(result.totalBytes),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "No attachments match this filter.",
                  style: context.theme.textTheme.bodyMedium?.copyWith(color: context.theme.colorScheme.outline),
                ),
              ),
            ),
          if (visibleSegments.isNotEmpty) ...[
            const SizedBox(height: 24),
            M3ESectionHeader(label: "Breakdown"),
            Obx(() => M3ESection(
                  backgroundColor: context.tileColor,
                  margin: EdgeInsets.zero,
                  children: [
                    for (final segment in visibleSegments)
                      _SegmentTile(
                        segment: segment,
                        totalBytes: result.totalBytes,
                        selected: controller.selectedSegments.contains(segment.type),
                        onTap: () => controller.toggleSegment(segment.type),
                      ),
                  ],
                )),
          ],
          if (!result.globalScanValid)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                "Orphaned files and link previews aren't shown while a chat or age filter is active.",
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

/// One segment row — `M3EListTile` plus an inline linear progress bar below
/// it. `M3EListTile` has no built-in progress-bar slot, so this composes the
/// primitive rather than changing it.
class _SegmentTile extends StatelessWidget with StorageAnalyzerHelpersMixin {
  const _SegmentTile({
    required this.segment,
    required this.totalBytes,
    required this.selected,
    required this.onTap,
  });

  final StorageSegment segment;
  final int totalBytes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final config = StorageAnalyzerHelpersMixin.segmentConfig[segment.type]!;
    final share = totalBytes == 0 ? 0.0 : segment.bytes / totalBytes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        M3EListTile(
          icon: config.materialIcon,
          title: config.label,
          supportingText:
              "${formatBytes(segment.bytes)} · ${segment.fileCount} file${segment.fileCount == 1 ? '' : 's'}",
          trailing: Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? context.theme.colorScheme.primary : context.theme.colorScheme.outline,
          ),
          onTap: onTap,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 4,
              backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorFor(context, segment.type)),
            ),
          ),
        ),
      ],
    );
  }
}
