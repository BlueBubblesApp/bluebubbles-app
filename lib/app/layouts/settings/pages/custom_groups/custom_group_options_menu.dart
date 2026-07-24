import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/widgets.dart';

/// Per-group "more options" sheet, reached via the "⋯" affordance on a
/// custom group row in the settings list. Exists as a separate entry point
/// from the chat selector page (which only edits group membership) so that
/// group-level options like [CustomGroup.showUnreadBadge] have somewhere to
/// live without cluttering that flow.
Future<void> showCustomGroupOptionsMenu(
  BuildContext context, {
  required CustomGroup group,
  required VoidCallback onRename,
  required VoidCallback onEditChats,
  required VoidCallback onToggleUnreadBadge,
  required VoidCallback onDelete,
}) async {
  final action = await showBBListSelector<String>(
    context: context,
    title: group.name,
    options: [
      const BBListSelectorOption(label: "Rename", value: "rename"),
      const BBListSelectorOption(label: "Edit Chats", value: "edit_chats"),
      BBListSelectorOption(
        label: group.showUnreadBadge ? "Hide Unread Badge" : "Show Unread Badge",
        value: "toggle_unread_badge",
      ),
      const BBListSelectorOption(label: "Delete", value: "delete", isDestructive: true),
    ],
  );

  switch (action) {
    case "rename":
      onRename();
      break;
    case "edit_chats":
      onEditChats();
      break;
    case "toggle_unread_badge":
      onToggleUnreadBadge();
      break;
    case "delete":
      onDelete();
      break;
  }
}
