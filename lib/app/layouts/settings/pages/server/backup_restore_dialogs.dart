import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

import 'backup_restore_types.dart';

class BackupRestoreDialogs {
  static Future<BackupDestination?> showBackupDestinationDialog(BuildContext context) {
    return showBBDialog<BackupDestination>(
      context: context,
      title: "Choose Backup Location",
      body:
          "Local - Save a backup to this device.\nCloud - Save a backup to the server for use across all your devices.",
      actions: [
        BBDialogAction(
          text: "Local",
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(BackupDestination.local),
        ),
        BBDialogAction(
          text: "Cloud",
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(BackupDestination.cloud),
        ),
      ],
    );
  }

  static Future<void> showConfirmation({
    required BuildContext context,
    required String title,
    required Widget content,
    required VoidCallback onYes,
    VoidCallback? onNo,
  }) {
    return showAreYouSure(
      context,
      title: title,
      content: content,
      onNo: onNo ?? () => Navigator.of(context, rootNavigator: true).pop(),
      onYes: onYes,
    );
  }

  /// Shown only when one or more pinned chats couldn't be matched on import —
  /// callers should skip this dialog entirely when [skipped] is empty.
  static Future<void> showPinnedChatsRestoreSummary({
    required BuildContext context,
    required List<String> skipped,
  }) {
    return showBBDialog(
      context: context,
      title: "Some Pinned Chats Couldn't Be Restored",
      content: SizedBox(
        width: NavigationSvc.width(context) * 3 / 5,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final label in skipped) Text("• $label"),
            ],
          ),
        ),
      ),
      actions: [
        BBDialogAction(
          text: "Close",
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }

  static Future<void> showJsonData({
    required BuildContext context,
    required String title,
    required String jsonText,
  }) {
    return showBBDialog(
      context: context,
      title: title,
      content: SizedBox(
        width: NavigationSvc.width(context) * 3 / 5,
        height: MediaQuery.of(context).size.height * 1 / 4,
        child: Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              jsonText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ),
      actions: [
        BBDialogAction(
          text: "Close",
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }
}
