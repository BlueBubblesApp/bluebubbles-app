import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

/// Resolves the per-chat theme, scaffold header/tile colours, and the bubble-colour `primary`
/// override used by the conversation details + attachments pages.
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
    final reverseMapping = SettingsSvc.settings.skin.value == Skins.Material && isDark;
    final rawHeaderColor = (isDark ? baseTheme.colorScheme.surface : baseTheme.colorScheme.surfaceContainerHighest)
        .withAlpha(hasWindowEffect ? 20 : 255);
    final rawTileColor = (isDark ? baseTheme.colorScheme.surfaceContainerHighest : baseTheme.colorScheme.surface)
        .withAlpha(hasWindowEffect ? 100 : 255);
    final scaffoldHeaderColor = reverseMapping ? rawTileColor : rawHeaderColor;
    final scaffoldTileColor = reverseMapping ? rawHeaderColor : rawTileColor;

    final bubbleColors = baseTheme.extensions[BubbleColors] as BubbleColors?;
    final bubbleColor = chat.isIMessage
        ? bubbleColors?.iMessageBubbleColor ?? baseTheme.colorScheme.iMessageBubble
        : bubbleColors?.smsBubbleColor ?? baseTheme.colorScheme.smsBubble;
    final onBubbleColor = chat.isIMessage
        ? bubbleColors?.oniMessageBubbleColor ?? baseTheme.colorScheme.oniMessageBubble
        : bubbleColors?.onSmsBubbleColor ?? baseTheme.colorScheme.onSmsBubble;
    final useGeneratedThemeSurface = themeName != null
        ? ThemesService.isGeneratedMaterialThemeName(themeName)
        : ThemeSvc.isMaterialYouActive(context);

    final resolvedTheme = baseTheme.copyWith(
      primaryColor: bubbleColor,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: bubbleColor,
        onPrimary: onBubbleColor,
        surface: useGeneratedThemeSurface ? null : bubbleColors?.receivedBubbleColor,
        onSurface: useGeneratedThemeSurface ? null : bubbleColors?.onReceivedBubbleColor,
      ),
    );

    return ChatDetailTheme(
      theme: resolvedTheme,
      headerColor: scaffoldHeaderColor,
      tileColor: scaffoldTileColor,
    );
  }
}
