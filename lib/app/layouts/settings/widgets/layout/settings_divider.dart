import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsDivider extends StatelessWidget {
  final double thickness;
  final Color? color;
  final EdgeInsets padding;

  const SettingsDivider({
    this.thickness = 1,
    this.color,
    this.padding = const EdgeInsets.only(left: 66.0),
  });

  @override
  Widget build(BuildContext context) {
    if (ss.settings.skin.value == Skins.iOS) {
      return Padding(
        padding: padding,
        child: Divider(
          color: color ?? context.theme.colorScheme.outline.withOpacity(0.5),
          thickness: 0.5,
          height: 0.5,
        )
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}