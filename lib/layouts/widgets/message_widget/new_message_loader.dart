import 'package:get/get.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NewMessageLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Loading more messages...",
            style: Get.theme.textTheme.subtitle2,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Theme(
            data: ThemeData(
              cupertinoOverrideTheme: CupertinoThemeData(brightness: Brightness.dark),
            ),
            child: CupertinoActivityIndicator(),
          ),
        ),
      ],
    );
  }
}
