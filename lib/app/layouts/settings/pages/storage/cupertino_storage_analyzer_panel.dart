import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_controller.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_analyze_prompt.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_filter_bar.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_free_up_fab.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_progress_section.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/widgets/storage_results_section.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

/// No pull-to-refresh and no manual refresh affordance, on any skin — the
/// page only ever re-analyzes on the initial "Analyze" tap, on a filter
/// change, or automatically after a delete (to verify it landed).
class CupertinoStorageAnalyzerPanel extends StatelessWidget with StorageAnalyzerHelpersMixin {
  const CupertinoStorageAnalyzerPanel({super.key, required this.controller});

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
          child: Column(
            children: [
              StorageFilterBar(controller: controller),
              Obx(() {
                final progress = controller.progress.value;
                if (progress.stage != null) {
                  return StorageProgressSection(progress: progress);
                }
                final result = controller.result.value;
                if (result == null) return StorageAnalyzePrompt(controller: controller);
                return StorageResultsSection(controller: controller, result: result);
              }),
            ],
          ),
        ),
      ],
    );
  }
}
