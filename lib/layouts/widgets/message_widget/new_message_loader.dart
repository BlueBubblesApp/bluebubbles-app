import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
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
            style: Theme.of(context).textTheme.subtitle2,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SettingsManager().settings.skin.value == Skins.iOS ? Theme(
            data: ThemeData(
              cupertinoOverrideTheme: CupertinoThemeData(brightness: Brightness.dark),
            ),
            child: CupertinoActivityIndicator(),
          ) : Container(height: 20, width: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2,))),
        ),
      ],
    );
  }
}
