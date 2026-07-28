import 'package:bluebubbles/app/layouts/settings/pages/storage/cupertino_storage_analyzer_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/material_storage_analyzer_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/samsung_storage_analyzer_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_controller.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Entry point for the Storage Analyzer settings page. Owns the controller's
/// lifecycle directly (unlike `imessage_stats_page.dart`, which reuses a
/// controller that already exists elsewhere) since nothing else needs it.
class StorageAnalyzerPanel extends StatefulWidget {
  const StorageAnalyzerPanel({super.key, this.initialChat});

  /// Pre-selects this chat's filter and immediately runs the first analysis
  /// — used by the "Storage" entry on the conversation details page so
  /// pivoting there from a chat lands on that chat's numbers, not the
  /// all-chats empty state.
  final Chat? initialChat;

  @override
  State<StorageAnalyzerPanel> createState() => _StorageAnalyzerPanelState();
}

class _StorageAnalyzerPanelState extends State<StorageAnalyzerPanel> {
  late final controller = Get.put(StorageAnalyzerController());

  @override
  void initState() {
    super.initState();
    if (widget.initialChat != null) {
      controller.selectedChat.value = widget.initialChat;
      controller.analyze();
    }
  }

  @override
  void dispose() {
    Get.delete<StorageAnalyzerController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher(
      iOSSkin: CupertinoStorageAnalyzerPanel(controller: controller),
      materialSkin: MaterialStorageAnalyzerPanel(controller: controller),
      samsungSkin: SamsungStorageAnalyzerPanel(controller: controller),
    );
  }
}
