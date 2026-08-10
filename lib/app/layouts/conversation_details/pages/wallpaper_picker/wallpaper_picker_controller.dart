import 'package:bluebubbles/app/components/wallpaper/wallpaper.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/wallpaper_picker/dynamic_wallpaper_config_page.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/background/background_crop.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared controller for the wallpaper picker page — one instance drives all
/// three skin variants (Cupertino/Material/Samsung), following the
/// `ContactsManagementController` pattern.
class WallpaperPickerController extends GetxController {
  WallpaperPickerController(this.chat);

  final Chat chat;

  ChatState? get chatState => ChatsSvc.getChatState(chat.guid);

  /// Opens the existing image-crop flow. `BackgroundCrop` persists the
  /// result itself (via `ChatsSvc.setChatCustomBackgroundPath`), which also
  /// flips `wallpaperType` to "image" — nothing further to do here.
  void pickImage(BuildContext context) {
    NavigationSvc.push(context, BackgroundCrop(chat: chat));
  }

  Future<void> removeWallpaper() async {
    await ChatsSvc.clearChatWallpaper(chat);
  }

  /// Opens the config screen for [definition] — pre-filled with the chat's
  /// current config when it's already the active dynamic wallpaper, or the
  /// definition's defaults otherwise.
  void openDynamicConfig(BuildContext context, DynamicWallpaperDefinition definition) {
    final state = chatState;
    final isCurrent = state?.wallpaperType.value == ChatWallpaperType.dynamic && state?.dynamicWallpaperId.value == definition.id;
    NavigationSvc.push(
      context,
      DynamicWallpaperConfigPage(
        chat: chat,
        definition: definition,
        initialConfig: isCurrent ? state?.dynamicWallpaperConfig.value : null,
      ),
    );
  }
}
