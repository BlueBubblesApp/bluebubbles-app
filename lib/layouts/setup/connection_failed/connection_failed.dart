import 'package:flutter/material.dart';

class ConnectionFailedPopup extends StatefulWidget {
  ConnectionFailedPopup({Key? key}) : super(key: key);

  @override
  _ConnectionFailedPopupState createState() => _ConnectionFailedPopupState();
}

class _ConnectionFailedPopupState extends State<ConnectionFailedPopup> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Connection Error!"),
      content: Text(
          "Ooops, looks like the app could not connect to the server. Please ensure that you are connected to wifi and that your server is online."),
      actions: [
        TextButton(
          child: Text(
            "Start over",
            style: Theme.of(context).textTheme.bodyText1!.apply(
                  color: Theme.of(context).primaryColor,
                ),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        )
      ],
    );
  }
}
