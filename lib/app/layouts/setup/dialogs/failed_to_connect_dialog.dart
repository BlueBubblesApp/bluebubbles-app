import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FailedToConnectDialog extends StatelessWidget {
  const FailedToConnectDialog({Key? key, required this.onDismiss}) : super(key: key);
  final Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        onDismiss();
        return true;
      },
      child: AlertDialog(
        backgroundColor: context.theme.colorScheme.properSurface,
        title: Text(
          "Failed To Connect!",
          style: context.theme.textTheme.titleLarge,
        ),
        content: Text(
          "Please make sure you are connected to the internet and your server is online!",
          style: context.theme.textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: onDismiss
          ),
        ],
      ),
    );
  }
}
