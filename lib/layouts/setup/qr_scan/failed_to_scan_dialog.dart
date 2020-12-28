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
    String error = exception.toString();
    if (error.contains("ROWID")) {
      error =
          "iMessage not configured on macOS device! Please configure an iCloud/Apple ID account!";
    }

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Text(
          error,
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
