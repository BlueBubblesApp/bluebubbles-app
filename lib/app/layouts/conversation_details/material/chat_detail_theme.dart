import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

/// Resolves the per-chat theme and scaffold header/tile colours used by the conversation
/// details + attachments pages.
///
/// Must be called from inside the `Obx` that already wraps this on both call sites — it reads
/// `chatState.themeVersion` / `customThemeDark` / `customThemeLight` reactively.
class ChatDetailTheme {
  final ThemeData theme;
  final Color headerColor;
  final Color tileColor;

  const ChatDetailTheme({
    required this.theme,
    required this.headerColor,
    required this.tileColor,
  });

  static ChatDetailTheme resolve(BuildContext context, Chat chat) {
    final chatState = ChatsSvc.getOrCreateChatState(chat);
    final isDark = ThemeSvc.inDarkMode(context);
    chatState.themeVersion.value;
    final themeName = isDark ? chatState.customThemeDark.value : chatState.customThemeLight.value;
    final baseTheme = ThemeStruct.resolveByName(themeName, isDark ? Brightness.dark : Brightness.light).data;

    // Compute scaffold colors from baseTheme before copyWith modifies colorScheme.surface.
    final hasWindowEffect = SettingsSvc.settings.windowEffect.value != WindowEffect.disabled;
    final scaffoldHeaderColor =
        (isDark ? baseTheme.colorScheme.surface : baseTheme.colorScheme.surfaceContainerHighest)
            .withAlpha(hasWindowEffect ? 20 : 255);
    final scaffoldTileColor =
        (isDark ? baseTheme.colorScheme.surfaceContainerHighest : baseTheme.colorScheme.surface)
            .withAlpha(hasWindowEffect ? 100 : 255);

    // Use the chat's selected theme as-is — no bubble-color accent override. Bubble colors are
    // tuned for contrast against the bubble itself, not against the tonal surfaces buttons, icons,
    // and text sit on throughout this page, and using them as `primary` reads as low-contrast/muddy
    // (e.g. "Show more" text, the "Add people" tonal icon) especially in dark mode.
    return ChatDetailTheme(
      theme: baseTheme,
      headerColor: scaffoldHeaderColor,
      tileColor: scaffoldTileColor,
    );
  }
}
