/// How a chat's background is rendered.
///
/// Stored on [Chat.wallpaperType] as [name]. `none` means no custom wallpaper
/// (falls back to the app-wide gradient/background); `image` means a static
/// custom background image (`Chat.customBackgroundPath`); `dynamic` means an
/// animated wallpaper resolved via [DynamicWallpaperRegistry] using
/// `Chat.dynamicWallpaperId` + `Chat.dynamicWallpaperConfig`.
enum ChatWallpaperType {
  none,
  image,
  dynamic;

  static ChatWallpaperType fromName(String? name) {
    return ChatWallpaperType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ChatWallpaperType.none,
    );
  }

  /// Resolves the effective wallpaper type for a chat, treating an unset
  /// [storedType] with an existing [imagePath] as "image" — chats that had a
  /// custom background before this enum existed never persisted a type, so
  /// they must still resolve to "image" rather than silently reverting to
  /// the default background.
  static ChatWallpaperType resolve(String? storedType, String? imagePath) {
    final type = fromName(storedType);
    if (type == ChatWallpaperType.none && imagePath != null && imagePath.isNotEmpty) {
      return ChatWallpaperType.image;
    }
    return type;
  }
}
