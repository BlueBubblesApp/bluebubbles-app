import 'package:bluebubbles/app/layouts/chat_selector_view/chat_selector_view.dart';
import 'package:bluebubbles/app/layouts/settings/pages/storage/storage_analyzer_controller.dart';
import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Chat + age filters, always visible so both are settable before the first
/// analysis. Reuses [ChatSelectorView] for the chat pick and [showBBListSelector]
/// for the age pick — see `docs/feature-planning/storage-analyzer/STORAGE_ANALYZER_PLAN.md`.
class StorageFilterBar extends StatelessWidget {
  const StorageFilterBar({super.key, required this.controller});

  final StorageAnalyzerController controller;

  void _pickChat(BuildContext context) {
    NavigationSvc.push(
      context,
      ChatSelectorView(
        onSelect: (chat) => controller.selectedChat.value = chat,
      ),
    );
  }

  Future<void> _pickAgeFilter(BuildContext context) async {
    final selected = await showBBListSelector<StorageAgeFilter>(
      context: context,
      title: "Filter by Age",
      options: StorageAgeFilter.values
          .map((f) => BBListSelectorOption<StorageAgeFilter>(label: f.label, value: f))
          .toList(),
    );
    if (selected != null) controller.ageFilter.value = selected;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Obx(() {
        final chat = controller.selectedChat.value;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BBChip(
              avatar: Icon(context.iOS ? CupertinoIcons.chat_bubble : Icons.chat_bubble_outline, size: 16),
              label: Text(chat?.getTitle() ?? "All Chats"),
              onPressed: () => _pickChat(context),
              onDeleted: chat != null ? () => controller.selectedChat.value = null : null,
            ),
            BBChip(
              avatar: Icon(context.iOS ? CupertinoIcons.calendar : Icons.calendar_today_outlined, size: 16),
              label: Text(controller.ageFilter.value.label),
              onPressed: () => _pickAgeFilter(context),
            ),
          ],
        );
      }),
    );
  }
}
