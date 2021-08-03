import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Widget buildBackButton(BuildContext context, {EdgeInsets padding = EdgeInsets.zero, double? iconSize, Skins? skin}) {
  return Container(
    padding: padding,
    width: 25,
    child: IconButton(
      iconSize: iconSize ?? 24,
      icon: skin != null ? Icon(skin == Skins.iOS ? Icons.arrow_back_ios : Icons.arrow_back,
          color: Theme.of(context).primaryColor) : Obx(() => Icon(SettingsManager().settings.skin.value == Skins.iOS ? Icons.arrow_back_ios : Icons.arrow_back,
          color: Theme.of(context).primaryColor)),
      onPressed: () {
        Get.back(closeOverlays: true);
      },
    ),
  );
}

Widget buildProgressIndicator(BuildContext context, {double height = 20, double width = 20, double strokeWidth = 2}) {
  return SettingsManager().settings.skin.value == Skins.iOS ? Theme(
    data: ThemeData(
      cupertinoOverrideTheme: CupertinoThemeData(
          brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor)),
    ),
    child: CupertinoActivityIndicator(
      radius: width / 2,
    ),
  ) : Container(
      constraints: BoxConstraints(maxHeight: height, maxWidth: width),
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
      )
  );
}
