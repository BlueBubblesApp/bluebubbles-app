import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SyncDialog extends StatefulWidget {
  SyncDialog({Key? key, required this.manager}) : super(key: key);

  final IncrementalSyncManager manager;

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends OptimizedState<SyncDialog> {

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.theme.colorScheme.properSurface,
      title: Obx(() => Text(widget.manager.progress.value >= 1 ? "Done syncing!" : "Syncing messages....", style: context.theme.textTheme.titleLarge)),
      content: Container(
        height: 5,
        child: Center(
          child: Obx(() => LinearProgressIndicator(
            value: widget.manager.progress.value,
            backgroundColor: context.theme.colorScheme.outline,
            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
          )),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            "OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
          ),
        )
      ],
    );
  }
}