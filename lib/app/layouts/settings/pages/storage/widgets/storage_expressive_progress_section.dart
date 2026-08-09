import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Expressive progress UI for the Material/Samsung skins — same content as
/// the iOS `StorageProgressSection` (stage label, monotonic bar, live byte
/// total), styled with the M3E type scale.
class StorageExpressiveProgressSection extends StatelessWidget with StorageAnalyzerHelpersMixin {
  const StorageExpressiveProgressSection({super.key, required this.progress});

  final StorageAnalysisProgress progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Text(
            progress.label,
            style: context.theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            formatBytes(progress.bytesSoFar),
            style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.outline),
          ),
          if (progress.total > 0) ...[
            const SizedBox(height: 2),
            Text(
              '${progress.processed} / ${progress.total}',
              style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.outline),
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 8,
              backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
