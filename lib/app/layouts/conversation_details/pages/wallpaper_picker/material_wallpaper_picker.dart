import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/wallpaper_picker_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/widgets/wallpaper_expressive_body.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';

/// Material M3 Expressive skin — built on `lib/app/components/m3e/`.
class MaterialWallpaperPicker extends StatelessWidget {
  const MaterialWallpaperPicker({super.key, required this.controller});

  final WallpaperPickerController controller;

  @override
  Widget build(BuildContext context) {
    return BBScaffold(
      appBar: BBAppBar(titleText: "Wallpaper", leading: buildBackButton(context)),
      body: WallpaperExpressiveBody(controller: controller),
    );
  }
}
