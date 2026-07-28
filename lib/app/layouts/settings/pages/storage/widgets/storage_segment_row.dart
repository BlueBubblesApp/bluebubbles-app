import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A single segment row — icon, label, inline linear progress bar (share of
/// the total), byte size, and file count. Tapping toggles selection, which
/// the Task 08 cleanup sheet reads off `StorageAnalyzerController.selectedSegments`.
///
/// This widget is only ever mounted from the iOS skin (`StorageResultsSection`),
/// so its icons are Cupertino-only, unlike the shared `StorageAnalyzerHelpersMixin`
/// config that branches per skin.
class StorageSegmentRow extends StatelessWidget with StorageAnalyzerHelpersMixin {
  const StorageSegmentRow({
    super.key,
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
    final color = colorFor(context, segment.type);
    final share = totalBytes == 0 ? 0.0 : segment.bytes / totalBytes;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SettingsLeadingIcon(iosIcon: config.iosIcon, materialIcon: config.materialIcon, containerColor: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(config.label, style: context.theme.textTheme.bodyMedium),
                      ),
                      Text(
                        formatBytes(segment.bytes),
                        style: context.theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 5,
                      backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${segment.fileCount} file${segment.fileCount == 1 ? '' : 's'}",
                    style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              color: selected ? context.theme.colorScheme.primary : context.theme.colorScheme.outline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
