import 'dart:async';

import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_controller.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/backend/interfaces/storage_interface.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class _StorageBytesFormatter with StorageAnalyzerHelpersMixin {
  const _StorageBytesFormatter();
}

const _bytesFormatter = _StorageBytesFormatter();

/// Confirmation + delete for whatever segments are currently selected on
/// [controller]. A single yes/no confirm, not a form — `showAreYouSure` is
/// the right primitive here rather than a custom bottom sheet.
Future<void> showStorageCleanupSheet(BuildContext context, StorageAnalyzerController controller) async {
  final segments = Set<StorageSegmentType>.from(controller.selectedSegments);
  if (segments.isEmpty) return;
  final bytes = controller.selectedBytes;

  // Link previews belong here too: they are regenerated on demand from the URL
  // in the message, and nothing about them lives on the server.
  final onlyDerivedOrOrphaned = segments.every((s) =>
      s == StorageSegmentType.thumbnailsAndConversions ||
      s == StorageSegmentType.orphaned ||
      s == StorageSegmentType.urlPreviews);

  await showAreYouSure(
    context,
    title: "Free up ${_bytesFormatter.formatBytes(bytes)}?",
    content: Text(
      onlyDerivedOrOrphaned
          ? "Selected cache files will be removed and regenerated automatically as needed. "
              "Nothing is deleted from your server."
          : "Selected files will be removed from this device and re-downloaded automatically the "
              "next time you open the relevant conversation. Nothing is deleted from your server.",
    ),
    yesText: "Delete",
    yesIsDestructive: true,
    onNo: () => Navigator.of(context, rootNavigator: true).pop(),
    onYes: () async {
      Navigator.of(context, rootNavigator: true).pop();
      final result = await StorageInterface.deleteAttachments(
        chatGuid: controller.selectedChat.value?.guid,
        ageFilter: controller.ageFilter.value,
        segments: segments,
      );
      // Re-run in the background so the results view reflects the new state —
      // this is the only "refresh" the page ever does automatically, to
      // verify the deletion actually landed.
      unawaited(controller.analyze());
      if (context.mounted) await _showDeleteSummary(context, result);
    },
  );
}

Future<void> _showDeleteSummary(BuildContext context, StorageDeleteResult result) {
  return showBBDialog<void>(
    context: context,
    title: "Storage Freed",
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SummaryRow(label: "Space freed", value: _bytesFormatter.formatBytes(result.bytesFreed)),
        _SummaryRow(label: "Files removed", value: "${result.filesDeleted}"),
        if (result.attachmentsReset > 0)
          _SummaryRow(
            label: "Will re-download",
            value: "${result.attachmentsReset} item${result.attachmentsReset == 1 ? '' : 's'}",
          ),
      ],
    ),
    actions: [
      BBDialogAction(
        text: "OK",
        isDefault: true,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    ],
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.theme.textTheme.bodyMedium?.copyWith(color: context.theme.colorScheme.outline)),
          Text(value, style: context.theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
