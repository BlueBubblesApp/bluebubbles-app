import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Name-entry dialog reused by both the "create new group" and "rename
/// group" flows. Returns the entered name, or null if cancelled.
Future<String?> showCreateGroupDialog(BuildContext context, {String? initialName}) {
  final controller = TextEditingController(text: initialName);
  return showBBDialog<String>(
    context: context,
    title: initialName == null ? "New Group" : "Rename Group",
    content: TextField(
      controller: controller,
      autofocus: true,
      decoration: InputDecoration(
        labelText: "Group Name",
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: context.theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: context.theme.colorScheme.primary),
        ),
      ),
    ),
    actions: [
      BBDialogAction(
        text: "Cancel",
        // showBBDialog pushes with useRootNavigator: true, so popping must target
        // the root navigator too — otherwise Navigator.of(context) (context here
        // being the original caller's, not the dialog's own) can resolve to a
        // nested Navigator and fail to dismiss this dialog.
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      BBDialogAction(
        text: "Save",
        isDefault: true,
        onPressed: () {
          final name = controller.text.trim();
          if (name.isEmpty) return;
          Navigator.of(context, rootNavigator: true).pop(name);
        },
      ),
    ],
  );
}
