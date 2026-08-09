import 'package:bluebubbles/app/components/wallpaper/wallpaper.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Shows the chat's currently active wallpaper (static image or live dynamic
/// preview) with a "Remove" action, or an empty placeholder when none is
/// set. Visually the same on every skin — like `ContactAvatarWidget`, a
/// media preview card doesn't need three different looks — the picker pages
/// around it provide the skin-specific chrome.
class WallpaperCurrentPreview extends StatelessWidget {
  final ChatState? chatState;
  final VoidCallback onRemove;

  const WallpaperCurrentPreview({super.key, required this.chatState, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final type = chatState?.wallpaperType.value ?? ChatWallpaperType.none;
      final imagePath = chatState?.customBackgroundPath.value;

      Widget preview;
      if (type == ChatWallpaperType.dynamic) {
        preview = DynamicWallpaperView(
          wallpaperId: chatState?.dynamicWallpaperId.value,
          config: chatState?.dynamicWallpaperConfig.value,
        );
      } else if (type == ChatWallpaperType.image && imagePath != null) {
        preview = Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } else {
        preview = Center(
          child: Text(
            "No wallpaper set",
            style: context.theme.textTheme.bodyMedium?.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 180,
              color: context.theme.colorScheme.surfaceContainerHighest,
              child: preview,
            ),
          ),
          if (type != ChatWallpaperType.none) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline, color: context.theme.colorScheme.error, size: 18),
                label: Text("Remove wallpaper", style: TextStyle(color: context.theme.colorScheme.error)),
              ),
            ),
          ],
        ],
      );
    });
  }
}
