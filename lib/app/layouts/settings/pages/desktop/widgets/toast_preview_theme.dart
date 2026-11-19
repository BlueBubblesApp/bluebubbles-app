import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:win32/win32.dart';

/// Colors for the desktop settings' notification preview and action picker.
///
/// [read] is how a Windows notification looks under the user's Personalization settings. The accent mix and overlays
/// were measured against a real notification on Windows 11 (dark mode, accent on Start and taskbar); the neutral
/// backgrounds are Windows' acrylic fallback colors. [fromAppTheme] is for Linux, whose notifications look different
/// on every desktop, so its action picker just uses the app's theme.
class ToastPreviewTheme {
  const ToastPreviewTheme({
    required this.background,
    required this.button,
    required this.border,
    required this.text,
    required this.subtext,
  });

  final Color background;
  final Color button;
  final Color border;
  final Color text;
  final Color subtext;

  @override
  bool operator ==(Object other) =>
      other is ToastPreviewTheme &&
      other.background == background &&
      other.button == button &&
      other.border == border &&
      other.text == text &&
      other.subtext == subtext;

  @override
  int get hashCode => Object.hash(background, button, border, text, subtext);

  static ToastPreviewTheme fromAppTheme(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return ToastPreviewTheme(
      background: scheme.surfaceContainerHighest,
      button: Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.065), scheme.surfaceContainerHighest),
      border: Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.125), scheme.surfaceContainerHighest),
      text: scheme.onSurface,
      subtext: scheme.onSurfaceVariant,
    );
  }

  static const String _personalize = r'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';

  static ToastPreviewTheme read() {
    final light = _dword(_personalize, 'SystemUsesLightTheme') == 1;
    // Windows only offers the accent on Start and taskbar in dark mode
    final accent = !light && _dword(_personalize, 'ColorPrevalence') == 1 ? _accentShade() : null;
    final background = accent != null
        // The notification's acrylic darkens the accent a little
        ? Color.lerp(accent, const Color(0xFF202020), 0.15)!
        : light
        ? const Color(0xFFF9F9F9)
        : const Color(0xFF2C2C2C);
    final foreground = light ? Colors.black : Colors.white;
    return ToastPreviewTheme(
      background: background,
      button: Color.alphaBlend(foreground.withValues(alpha: 0.065), background),
      border: Color.alphaBlend(foreground.withValues(alpha: 0.125), background),
      text: foreground,
      subtext: foreground.withValues(alpha: 0.78),
    );
  }

  static int? _dword(String key, String value) => using((arena) {
    final data = arena<Uint32>();
    final size = arena<Uint32>()..value = sizeOf<Uint32>();
    final result = RegGetValue(
      HKEY_CURRENT_USER,
      arena.pcwstr(key),
      arena.pcwstr(value),
      RRF_RT_REG_DWORD,
      null,
      data.cast(),
      size,
    );
    return result == ERROR_SUCCESS ? data.value : null;
  });

  /// The accent shade Start, the taskbar and notifications are drawn in: the sixth of the eight in AccentPalette
  static Color? _accentShade() => using((arena) {
    final data = arena<Uint8>(32);
    final size = arena<Uint32>()..value = 32;
    final result = RegGetValue(
      HKEY_CURRENT_USER,
      arena.pcwstr(r'Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'),
      arena.pcwstr('AccentPalette'),
      RRF_RT_REG_BINARY,
      null,
      data.cast(),
      size,
    );
    if (result != ERROR_SUCCESS || size.value < 24) return null;
    return Color.fromARGB(255, data[20], data[21], data[22]);
  });
}
