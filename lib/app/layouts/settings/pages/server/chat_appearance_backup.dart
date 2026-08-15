import 'package:bluebubbles/app/components/wallpaper/wallpaper.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/chat_backup_identifier.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';

/// Result of restoring a `chatAppearance` backup entry list.
class ChatAppearanceRestoreResult {
  final List<String> restored;
  final List<String> skipped;

  const ChatAppearanceRestoreResult({required this.restored, required this.skipped});
}

/// Exports/imports per-chat appearance — the chat's custom light/dark theme
/// selection and its wallpaper — in a server/device-agnostic way for the
/// Settings backup/restore feature. Chats are identified via
/// [ChatBackupIdentifier] (displayName/participant addresses) rather than
/// `chat.guid`, since guids are server-assigned and don't stay stable across
/// servers/reinstalls.
///
/// Two things are deliberately *not* portable and are therefore left out:
///
/// * **Image wallpapers** ([ChatWallpaperType.image]) — the selection is just a
///   path to a file in this device's app storage. Carrying it across devices
///   would mean embedding the image bytes in the backup JSON, which is out of
///   scope here. Chats using one are reported as skipped on export.
/// * **Adaptive-background themes** — those theme names are generated per chat
///   guid from that chat's background image ([ThemesService.adaptiveBackgroundThemeName]),
///   so they're meaningless on another device and can't be regenerated without
///   the image. They're treated as "no custom theme".
///
/// Themes are stored by **name**. On restore a name is only applied when a
/// theme with that name already exists on the destination device — restore the
/// Theme backup first if a per-chat theme comes up missing. Likewise a dynamic
/// wallpaper is only applied when its id is still present in
/// [DynamicWallpaperRegistry], so a backup referencing a wallpaper this build
/// doesn't ship is skipped rather than leaving the chat pointing at nothing.
///
/// Restore is additive: an entry only ever *sets* the fields it carries. It
/// never clears a theme or wallpaper the destination chat already has.
class ChatAppearanceBackup {
  static ChatAppearanceExport export() {
    final entries = <Map<String, dynamic>>[];
    final skipped = <String>[];

    for (final chat in ChatsSvc.allChats) {
      final state = ChatsSvc.getChatState(chat.guid);
      final light = _portableThemeName(state?.customThemeLight.value ?? chat.customThemeLight);
      final dark = _portableThemeName(state?.customThemeDark.value ?? chat.customThemeDark);
      final wallpaperType = _wallpaperType(chat, state);
      final wallpaper = _exportWallpaper(chat, state, wallpaperType);

      if (wallpaperType == ChatWallpaperType.image) {
        skipped.add("${_label(chat)} (image wallpapers aren't included in backups)");
      }
      if (light == null && dark == null && wallpaper == null) continue;

      entries.add({
        ...ChatBackupIdentifier.export(chat),
        if (light != null) "customThemeLight": light,
        if (dark != null) "customThemeDark": dark,
        if (wallpaper != null) "wallpaper": wallpaper,
      });
    }

    return ChatAppearanceExport(entries: entries, skipped: skipped);
  }

  static Future<ChatAppearanceRestoreResult> restore(List<dynamic> entries) async {
    final restored = <String>[];
    final skipped = <String>[];

    for (final entry in List<Map<String, dynamic>>.from(entries)) {
      final displayName = entry["displayName"] as String?;
      final participants = List<String>.from(entry["participants"] as List? ?? []);
      final label = !isNullOrEmpty(displayName) ? displayName! : participants.join(", ");

      final result = ChatBackupIdentifier.resolve(entry, ChatsSvc.allChats);
      if (result.match == null) {
        skipped.add("$label (${result.skipReason})");
        continue;
      }

      final match = result.match!;
      final applied = <String>[];

      final themeSkip = await _restoreThemes(match, entry, applied);
      if (themeSkip != null) skipped.add("$label: $themeSkip");

      final wallpaperSkip = await _restoreWallpaper(match, entry, applied);
      if (wallpaperSkip != null) skipped.add("$label: $wallpaperSkip");

      if (applied.isNotEmpty) {
        restored.add("$label (${applied.join(", ")})");
      }
    }

    return ChatAppearanceRestoreResult(restored: restored, skipped: skipped);
  }

  // ---------------------------------------------------------------------------------------------
  // Export helpers
  // ---------------------------------------------------------------------------------------------

  /// A theme name worth writing to a backup — null (follow the global theme)
  /// and device-local adaptive-background names both come back as null.
  static String? _portableThemeName(String? name) {
    if (isNullOrEmpty(name)) return null;
    if (ThemesService.isAdaptiveBackgroundThemeName(name!)) return null;
    return name;
  }

  static ChatWallpaperType _wallpaperType(Chat chat, ChatState? state) {
    return state?.wallpaperType.value ??
        ChatWallpaperType.resolve(chat.wallpaperType, FilesystemSvc.getExistingChatBackgroundPath(chat.guid));
  }

  static Map<String, dynamic>? _exportWallpaper(Chat chat, ChatState? state, ChatWallpaperType type) {
    // `none` has nothing to carry; `image` is a device-local file path (see the
    // class doc) and is reported to the caller as skipped instead.
    if (type != ChatWallpaperType.dynamic) return null;

    final id = state?.dynamicWallpaperId.value ?? chat.dynamicWallpaperId;
    if (isNullOrEmpty(id)) return null;

    // Stored decoded so the wallpaper's sub-config is readable/diffable JSON in
    // the backup file rather than an escaped string blob.
    final config = state?.dynamicWallpaperConfig.value ?? WallpaperConfigCodec.decode(chat.dynamicWallpaperConfig);

    return {
      "type": type.name,
      "id": id,
      "config": config ?? const <String, dynamic>{},
    };
  }

  static String _label(Chat chat) {
    if (!isNullOrEmpty(chat.displayName)) return chat.displayName!;
    return chat.handles.map((h) => h.address).join(", ");
  }

  // ---------------------------------------------------------------------------------------------
  // Restore helpers
  // ---------------------------------------------------------------------------------------------

  /// Applies the entry's theme names to [chat], keeping the chat's existing
  /// selection for any side the backup doesn't carry or the device doesn't
  /// have. Returns a skip reason when a named theme is missing locally.
  static Future<String?> _restoreThemes(Chat chat, Map<String, dynamic> entry, List<String> applied) async {
    final backupLight = entry["customThemeLight"] as String?;
    final backupDark = entry["customThemeDark"] as String?;
    if (isNullOrEmpty(backupLight) && isNullOrEmpty(backupDark)) return null;

    final state = ChatsSvc.getChatState(chat.guid);
    final currentLight = state?.customThemeLight.value ?? chat.customThemeLight;
    final currentDark = state?.customThemeDark.value ?? chat.customThemeDark;
    var light = currentLight;
    var dark = currentDark;

    final missing = <String>[];
    if (!isNullOrEmpty(backupLight)) {
      if (_themeExists(backupLight!)) {
        light = backupLight;
      } else {
        missing.add(backupLight);
      }
    }
    if (!isNullOrEmpty(backupDark)) {
      if (_themeExists(backupDark!)) {
        dark = backupDark;
      } else {
        missing.add(backupDark);
      }
    }

    if (light != currentLight || dark != currentDark) {
      await ChatsSvc.setChatCustomThemes(chat, lightTheme: light, darkTheme: dark);
      applied.add("theme");
    }

    if (missing.isEmpty) return null;
    final uniqueMissing = missing.toSet();
    final names = uniqueMissing.map((n) => "\"$n\"").join(", ");
    return "theme${uniqueMissing.length > 1 ? "s" : ""} $names not found on this device";
  }

  static bool _themeExists(String name) {
    if (ThemeStruct.findOne(name) != null) return true;
    return ThemesService.defaultThemes.any((t) => t.name == name);
  }

  /// Applies the entry's wallpaper to [chat]. Returns a skip reason when the
  /// backup references a wallpaper this build can't render.
  static Future<String?> _restoreWallpaper(Chat chat, Map<String, dynamic> entry, List<String> applied) async {
    final raw = entry["wallpaper"] as Map?;
    if (raw == null) return null;
    final wallpaper = Map<String, dynamic>.from(raw);

    final type = ChatWallpaperType.fromName(wallpaper["type"] as String?);
    if (type != ChatWallpaperType.dynamic) {
      return "wallpaper type \"${wallpaper["type"]}\" can't be restored";
    }

    final id = wallpaper["id"] as String?;
    if (isNullOrEmpty(id)) return "dynamic wallpaper entry has no id";
    if (DynamicWallpaperRegistry.byId(id) == null) {
      return "dynamic wallpaper \"$id\" isn't available in this version";
    }

    final config = Map<String, dynamic>.from(wallpaper["config"] as Map? ?? const {});
    await ChatsSvc.setChatDynamicWallpaper(chat, id!, config);
    applied.add("wallpaper");
    return null;
  }
}

/// Result of building a `chatAppearance` backup entry list — the entries plus
/// any chats whose appearance couldn't be represented portably.
class ChatAppearanceExport {
  final List<Map<String, dynamic>> entries;
  final List<String> skipped;

  const ChatAppearanceExport({required this.entries, required this.skipped});
}
