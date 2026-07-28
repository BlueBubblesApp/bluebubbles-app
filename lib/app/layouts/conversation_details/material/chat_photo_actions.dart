import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Photo business logic for a chat's avatar, shared by the iOS (`ChatInfo`) and
/// Material/Samsung (`ExpressiveChatHeader`) hero rows. Pure extraction — behavior is
/// identical to what `ChatInfo` used to do inline.
Future<bool?> showMethodDialog(BuildContext context, Chat chat, String title) async {
  return await showBBDialog<bool>(
    context: context,
    title: title,
    content: SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage
        ? Text(
            "Local - Changes only apply to this device.\nPrivate API - Changes will apply to everyone's devices.",
            style: context.theme.textTheme.bodyLarge,
          )
        : null,
    actions: [
      BBDialogAction(
        text: "Local",
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
      ),
      BBDialogAction(
        text: "Private API",
        isDefault: true,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
      ),
    ],
  );
}

Future<void> updatePhoto(BuildContext context, Chat chat) async {
  bool? papi = false;
  if (SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup) {
    papi = await showMethodDialog(context, chat, "Group Icon Update Method");
  }
  if (papi == null) return;
  final usePrivateApi = papi;
  if (!context.mounted) return;
  final String? result = await Navigator.of(context).push(
    ThemeSwitcher.buildPageRoute(
      builder: (context) => AvatarCrop(chat: chat),
    ),
  );
  if (result == null) return;

  if (!usePrivateApi) {
    await ChatsSvc.setChatCustomAvatarPath(chat, result);
    return;
  }

  if (usePrivateApi &&
      SettingsSvc.settings.enablePrivateAPI.value &&
      SettingsSvc.serverDetails.isMinBigSur &&
      SettingsSvc.serverDetails.supportsGroupChatManagement) {
    if (!context.mounted) return;
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
            title: Text(
              "Updating group photo...",
              style: context.theme.textTheme.titleLarge,
            ),
            content: SizedBox(
              height: 70,
              child: Center(
                child: CircularProgressIndicator(
                  backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                ),
              ),
            ),
          );
        });
    final response = await HttpSvc.chat.setIcon(chat.guid, result);
    if (response.statusCode == 200) {
      await ChatsSvc.setChatCustomAvatarPath(chat, result);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      showSnackbar("Notice", "Updated group photo successfully!");
    } else {
      try {
        await File(result).delete();
      } catch (_) {}
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      showSnackbar("Error", "Failed to update group photo!");
    }
  } else if (usePrivateApi) {
    try {
      await File(result).delete();
    } catch (_) {}
    showSnackbar("Error", "Failed to update group photo!");
  }
}

Future<void> deletePhoto(BuildContext context, Chat chat) async {
  bool? papi = false;
  if (SettingsSvc.settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup) {
    papi = await showMethodDialog(context, chat, "Group Icon Deletion Method");
  }
  if (papi == null) return;
  final usePrivateApi = papi;

  if (usePrivateApi &&
      SettingsSvc.settings.enablePrivateAPI.value &&
      SettingsSvc.serverDetails.isMinBigSur &&
      SettingsSvc.serverDetails.supportsGroupChatManagement) {
    final response = await HttpSvc.chat.removeIcon(chat.guid);
    if (response.statusCode == 200) {
      await ChatsSvc.setChatCustomAvatarPath(chat, null);
      showSnackbar("Notice", "Deleted group photo successfully!");
    } else {
      showSnackbar("Error", "Failed to delete group photo!");
    }
    return;
  }

  await ChatsSvc.setChatCustomAvatarPath(chat, null);
}
