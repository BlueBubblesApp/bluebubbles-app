import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NewMessageLoader extends StatelessWidget {
  final String? text;

  const NewMessageLoader({this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            text ?? "Loading more messages...",
            style: context.theme.textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.outline),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ss.settings.skin.value == Skins.iOS ? Theme(
            data: ThemeData(
              cupertinoOverrideTheme: const CupertinoThemeData(brightness: Brightness.dark),
            ),
            child: const CupertinoActivityIndicator(),
          ) : const SizedBox(
            height: 20,
            width: 20,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2)
            )
          ),
        ),
      ],
    );
  }
}
