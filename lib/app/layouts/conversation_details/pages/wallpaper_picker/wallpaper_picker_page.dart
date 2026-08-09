import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/cupertino_wallpaper_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/material_wallpaper_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/samsung_wallpaper_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/wallpaper_picker_controller.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Entry point for the chat wallpaper picker — reached from "Custom
/// Background" in conversation details. Shows the current wallpaper (with a
/// remove action), an option to pick a static image, and a live-preview
/// gallery of dynamic (animated) wallpapers.
class WallpaperPickerPage extends StatefulWidget {
  const WallpaperPickerPage({super.key, required this.chat});

  final Chat chat;

  @override
  State<WallpaperPickerPage> createState() => _WallpaperPickerPageState();
}

class _WallpaperPickerPageState extends State<WallpaperPickerPage> {
  late final controller = Get.isRegistered<WallpaperPickerController>(tag: widget.chat.guid)
      ? Get.find<WallpaperPickerController>(tag: widget.chat.guid)
      : Get.put(WallpaperPickerController(widget.chat), tag: widget.chat.guid);

  @override
  void dispose() {
    Get.delete<WallpaperPickerController>(tag: widget.chat.guid);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher(
      iOSSkin: CupertinoWallpaperPicker(controller: controller),
      materialSkin: MaterialWallpaperPicker(controller: controller),
      samsungSkin: SamsungWallpaperPicker(controller: controller),
    );
  }
}
