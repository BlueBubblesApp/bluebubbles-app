import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Widget buildBackButton(BuildContext context, {EdgeInsets padding = EdgeInsets.zero}) {
  return Container(
    padding: padding,
    width: 25,
    child: IconButton(
      icon: Icon(SettingsManager().settings.skin == Skins.iOS ? Icons.arrow_back_ios : Icons.arrow_back,
          color: Theme.of(context).primaryColor),
      onPressed: () {
        Navigator.of(context).pop();
      },
    ),
  );
}
