import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';

class FailedToScan extends StatelessWidget {
  const FailedToScan(
      {Key key,
      @required this.exception,
      @required this.title,
      this.showCopy = true})
      : super(key: key);
  final exception;
  final String title;
  final bool showCopy;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        physics: ThemeSwitcher.getScrollPhysics(),
        child: Text(
          exception.toString(),
        ),
      ),
      actions: [
        FlatButton(
          child: Text(
            "Ok",
            style: Theme.of(context)
                .textTheme
                .bodyText1
                .apply(color: Theme.of(context).primaryColor),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (showCopy)
          FlatButton(
            child: Text(
              "Copy",
              style: Theme.of(context)
                  .textTheme
                  .bodyText1
                  .apply(color: Theme.of(context).primaryColor),
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
