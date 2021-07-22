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
