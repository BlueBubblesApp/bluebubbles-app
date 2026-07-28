import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Determinate progress UI shown while an analysis run is in flight — stage
/// label, a monotonic bar (never resets across the three stages), and a
/// live-updating byte total. See `STORAGE_ANALYZER_PLAN.md` § Live progress
/// reporting for why the bar is real rather than an indeterminate spinner.
class StorageProgressSection extends StatelessWidget with StorageAnalyzerHelpersMixin {
  const StorageProgressSection({super.key, required this.progress});

  final StorageAnalysisProgress progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Text(
            progress.label,
            style: context.theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            formatBytes(progress.bytesSoFar),
            style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.outline),
          ),
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
