import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsDivider extends StatelessWidget {
  final double thickness;
  final Color? color;

  SettingsDivider({
    this.thickness = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (SettingsManager().settings.skin.value == Skins.iOS) {
      return Divider(
        color: color ?? context.theme.colorScheme.outline.withOpacity(0.5),
        thickness: 0.5,
        height: 0.5,
      );
    } else {
      return Container();
    }
  }
}