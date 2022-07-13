import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class FailedToScanDialog extends StatelessWidget {
  const FailedToScanDialog({Key? key, required this.exception, required this.title}) : super(key: key);
  final dynamic exception;
  final String title;

  @override
  Widget build(BuildContext context) {
    String error = exception.toString();
    if (error.contains("ROWID")) {
      error = "iMessage is not configured on the macOS server, please sign in with an Apple ID and try again.";
    }

    return AlertDialog(
      title: Text(
        title,
        style: context.theme.textTheme.titleLarge,
      ),
      backgroundColor: context.theme.colorScheme.properSurface,
      content: SingleChildScrollView(
        physics: ThemeSwitcher.getScrollPhysics(),
        child: Text(
          error,
          style: context.theme.textTheme.bodyLarge
        ),
      ),
      actions: [
        TextButton(
          child: Text("Copy", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
          onPressed: () {
            Navigator.of(context).pop();
            Clipboard.setData(ClipboardData(text: error.toString()));
          },
        ),
        TextButton(
          child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
