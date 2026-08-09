import 'package:bluebubbles/app/layouts/conversation_details/material/chat_detail_theme.dart';
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
    // Colors throughout this page (the config screens' color swatches, the
    // gallery preview tiles) are drawn from `context.theme` -- without this
    // override they'd only ever see the global theme, ignoring a chat's own
    // custom theme, since this page is reached via a separate pushed route
    // rather than as a descendant of the conversation view's per-chat
    // `Theme`. `ChatDetailTheme.resolve` already falls back to the global
    // theme when the chat has none of its own.
    return Obx(() {
      final chatTheme = ChatDetailTheme.resolve(context, widget.chat);
      return Theme(
        data: chatTheme.theme,
        child: ThemeSwitcher(
          iOSSkin: CupertinoWallpaperPicker(controller: controller),
          materialSkin: MaterialWallpaperPicker(controller: controller),
          samsungSkin: SamsungWallpaperPicker(controller: controller),
        ),
      );
    });
  }
}
