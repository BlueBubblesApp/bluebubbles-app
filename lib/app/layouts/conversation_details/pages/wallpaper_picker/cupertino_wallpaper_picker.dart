import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/wallpaper_picker_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/widgets/wallpaper_current_preview.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/widgets/wallpaper_gallery_grid.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS skin — Cupertino design language, no M3E (Material/Samsung only).
class CupertinoWallpaperPicker extends StatelessWidget {
  const CupertinoWallpaperPicker({super.key, required this.controller});

  final WallpaperPickerController controller;

  @override
  Widget build(BuildContext context) {
    return BBScaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: context.headerColor,
      appBar: BBAppBar(titleText: "Wallpaper", leading: buildBackButton(context)),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WallpaperCurrentPreview(chatState: controller.chatState, onRemove: controller.removeWallpaper),
          ),
          SettingsHeader(
            iosSubtitle: context.iosSubtitle,
            materialSubtitle: context.materialSubtitle,
            text: "Choose an image",
          ),
          SettingsSection(
            backgroundColor: context.tileColor,
            children: [
              SettingsTile(
                leading: const SettingsLeadingIcon(
                  iosIcon: CupertinoIcons.photo,
                  materialIcon: Icons.photo_outlined,
                  containerColor: Colors.deepPurple,
                ),
                title: "Pick From Photos",
                subtitle: "Crop and blur a custom image",
                onTap: () => controller.pickImage(context),
              ),
            ],
          ),
          SettingsHeader(
            iosSubtitle: context.iosSubtitle,
            materialSubtitle: context.materialSubtitle,
            text: "Dynamic Wallpapers",
          ),
          WallpaperGalleryGrid(
            chatState: controller.chatState,
            onSelect: (definition) => controller.openDynamicConfig(context, definition),
          ),
        ],
      ),
    );
  }
}
