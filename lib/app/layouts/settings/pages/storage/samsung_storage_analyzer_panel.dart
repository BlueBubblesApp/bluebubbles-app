import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_controller.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_expressive_analyze_prompt.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_expressive_progress_section.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_expressive_results_section.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_filter_bar.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_free_up_fab.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Samsung M3 Expressive skin — identical structure to the Material skin;
/// `SettingsScaffold` already branches Samsung internally (collapsing
/// `SliverAppBar`, `bodySlivers` re-wrapped in a `NeverScrollableScrollPhysics`
/// inner scroll view). No pull-to-refresh and no manual refresh button, on
/// any skin — the page only ever re-analyzes on the initial "Analyze" tap,
/// on a filter change, or automatically after a delete (to verify it landed).
class SamsungStorageAnalyzerPanel extends StatelessWidget with StorageAnalyzerHelpersMixin {
  const SamsungStorageAnalyzerPanel({super.key, required this.controller});

  final StorageAnalyzerController controller;

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Storage Analyzer",
      initialHeader: null,
      iosSubtitle: context.iosSubtitle,
      materialSubtitle: context.materialSubtitle,
      tileColor: context.tileColor,
      headerColor: context.headerColor,
      fab: StorageFreeUpFab(controller: controller),
      bodySlivers: [
        SliverToBoxAdapter(
          child: Padding(
            // Horizontal inset is left to each child (filter bar, results
            // section) so it matches the rest of Settings' edge alignment —
            // `M3ESection`'s own default margin is already 16, and a page-level
            // wrapper here would double it up.
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                StorageFilterBar(controller: controller),
                const SizedBox(height: 8),
                Obx(() => _buildBody(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final progress = controller.progress.value;
    if (progress.stage != null) return StorageExpressiveProgressSection(progress: progress);
    final result = controller.result.value;
    if (result == null) return StorageExpressiveAnalyzePrompt(controller: controller);
    return StorageExpressiveResultsSection(controller: controller, result: result);
  }
}
