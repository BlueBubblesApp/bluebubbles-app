import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/custom_cupertino_text_field.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SettingsHeader extends StatelessWidget {
  final Color headerColor;
  final Color tileColor;
  final TextStyle? iosSubtitle;
  final TextStyle? materialSubtitle;
  final String text;

  SettingsHeader(
      {required this.headerColor,
        required this.tileColor,
        required this.iosSubtitle,
        required this.materialSubtitle,
        required this.text});

  @override
  Widget build(BuildContext context) {
    if (SettingsManager().settings.skin.value == Skins.Samsung) return SizedBox(height: 15);
    return Column(children: [
      Container(
          height: SettingsManager().settings.skin.value == Skins.iOS ? 60 : 40,
          alignment: Alignment.bottomLeft,
          color: SettingsManager().settings.skin.value == Skins.iOS ? headerColor : tileColor,
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0, left: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 15),
            child: Text(text.psCapitalize,
                style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
          )),
    ]);
  }
}