import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FailedToScan extends StatelessWidget {
  const FailedToScan({Key? key, required this.exception, required this.title, this.showCopy = true}) : super(key: key);
  final dynamic exception;
  final String title;
  final bool showCopy;

  @override
  Widget build(BuildContext context) {
    String error = exception.toString();
    if (error.contains("ROWID")) {
      error = "iMessage not configured on macOS device! Please configure an iCloud/Apple ID account!";
    }

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        physics: ThemeSwitcher.getScrollPhysics(),
        child: Text(
          error,
        ),
      ),
      actions: [
        TextButton(
          child: Text(
            "Ok",
            style: Theme.of(context).textTheme.bodyText1!.apply(color: Theme.of(context).primaryColor),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (showCopy)
          TextButton(
            child: Text(
              "Copy",
              style: Theme.of(context).textTheme.bodyText1!.apply(color: Theme.of(context).primaryColor),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: exception));
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}
