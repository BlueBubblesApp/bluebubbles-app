import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FailedToConnectDialog extends StatelessWidget {
  const FailedToConnectDialog({super.key, required this.onDismiss});
  final Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: <T>(bool didPop, T? result) async {
        if (didPop) return;
        onDismiss();
        Navigator.of(context).pop();
      },
      child: AlertDialog(
        backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
        title: Text(
          SocketSvc.authFailed.value ? "Incorrect Password" : "Failed To Connect!",
          style: context.theme.textTheme.titleLarge,
        ),
        content: Text(
          SocketSvc.authFailed.value
              ? "The server rejected the password. Check it and try again."
              : "Please make sure you are connected to the internet and your server is online!",
          style: context.theme.textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
              onPressed: onDismiss,
              child: Text("OK",
                  style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary))),
        ],
      ),
    );
  }
}
