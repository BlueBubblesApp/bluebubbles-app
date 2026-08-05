import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_controller.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_cleanup_sheet.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Floating "Free up N" action, shared by all three skins via
/// `SettingsScaffold(fab: ...)`. Replaces the old inline footer button that
/// used to live at the bottom of the results list.
///
/// Always mounted (never swapped for `null`) so the scale/fade below is what
/// drives visibility — pops in with a little overshoot when the selection
/// goes from empty to non-empty, and eases back out when it's cleared.
/// `IgnorePointer` keeps the invisible FAB from eating taps in its footprint.
class StorageFreeUpFab extends StatelessWidget with StorageAnalyzerHelpersMixin {
  const StorageFreeUpFab({super.key, required this.controller});

  final StorageAnalyzerController controller;

  // Deliberately not a snappy 150-200ms (reads as a glitch), but 450ms felt
  // sluggish — this splits the difference.
  static const _duration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasSelection = controller.selectedSegments.isNotEmpty;
      final label = "Free up ${formatBytes(controller.selectedBytes)}";

      return IgnorePointer(
        ignoring: !hasSelection,
        child: AnimatedScale(
          scale: hasSelection ? 1.0 : 0.0,
          duration: _duration,
          curve: hasSelection ? Curves.easeOutBack : Curves.easeInCubic,
          child: AnimatedOpacity(
            opacity: hasSelection ? 1.0 : 0.0,
            duration: _duration,
            curve: Curves.easeOut,
            child: FloatingActionButton.extended(
              onPressed: () => showStorageCleanupSheet(context, controller),
              backgroundColor: context.theme.colorScheme.primary,
              foregroundColor: context.theme.colorScheme.onPrimary,
              icon: Icon(context.iOS ? CupertinoIcons.trash : Icons.delete_outline),
              label: Text(label),
            ),
          ),
        ),
      );
    });
  }
}
