import 'package:bluebubbles/app/components/m3e/m3e.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/wallpaper_picker_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/widgets/wallpaper_current_preview.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/widgets/wallpaper_gallery_grid.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';

/// Body shared by the Material and Samsung M3E skins.
class WallpaperExpressiveBody extends StatelessWidget {
  final WallpaperPickerController controller;

  const WallpaperExpressiveBody({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        WallpaperCurrentPreview(chatState: controller.chatState, onRemove: controller.removeWallpaper),
        const SizedBox(height: 16),
        const M3ESectionHeader(label: "Choose an image", padding: EdgeInsets.only(left: 4, bottom: 8)),
        M3ESection(
          backgroundColor: context.tileColor,
          margin: EdgeInsets.zero,
          children: [
            M3EListTile(
              icon: Icons.photo_outlined,
              title: "Pick from photos",
              supportingText: "Crop and blur a custom image",
              onTap: () => controller.pickImage(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const M3ESectionHeader(label: "Dynamic wallpapers", padding: EdgeInsets.only(left: 4, bottom: 8)),
        WallpaperGalleryGrid(
          chatState: controller.chatState,
          onSelect: (definition) => controller.openDynamicConfig(context, definition),
        ),
      ],
    );
  }
}
