import 'dart:convert';

/// JSON (de)serialization for `Chat.dynamicWallpaperConfig`. Kept as a plain
/// `Map<String, dynamic>` rather than a typed model per wallpaper type so
/// [DynamicWallpaperDefinition] implementations stay fully self-contained —
/// nothing outside a definition needs to know its config shape.
abstract final class WallpaperConfigCodec {
  static String encode(Map<String, dynamic> config) => jsonEncode(config);

  static Map<String, dynamic>? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
