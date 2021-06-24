import 'package:get/get.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';

class FailedToScan extends StatelessWidget {
  const FailedToScan({Key key, @required this.exception, @required this.title, this.showCopy = true}) : super(key: key);
  final exception;
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
        FlatButton(
          child: Text(
            "Ok",
            style: Get.theme.textTheme.bodyText1.apply(color: Get.theme.primaryColor),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (showCopy)
          FlatButton(
            child: Text(
              "Copy",
              style: Get.theme.textTheme.bodyText1.apply(color: Get.theme.primaryColor),
            ),
            onPressed: () {
              FlutterClipboard.copy(exception);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}
