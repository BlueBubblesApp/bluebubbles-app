import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  final List<Widget> children;
  final Color backgroundColor;

  SettingsSection({required this.children, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: settings.settings.skin.value == Skins.iOS
          ? const EdgeInsets.symmetric(horizontal: 10)
          : settings.settings.skin.value == Skins.Samsung
          ? const EdgeInsets.symmetric(vertical: 5)
          : EdgeInsets.zero,
      child: ClipRRect(
        borderRadius:
        settings.settings.skin.value == Skins.Samsung ? BorderRadius.circular(25) :
        settings.settings.skin.value == Skins.iOS ? BorderRadius.circular(10) : BorderRadius.circular(0),
        clipBehavior: settings.settings.skin.value != Skins.Material ? Clip.antiAlias : Clip.none,
        child: Container(
          color: backgroundColor,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}