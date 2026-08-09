import 'package:bluebubbles/app/components/wallpaper/wallpaper.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Grid of every registered dynamic wallpaper, each tile live-previewing
/// itself at default settings. New entries in [DynamicWallpaperRegistry]
/// show up here automatically — nothing here is aware of "wave" or
/// "floating" specifically.
class WallpaperGalleryGrid extends StatelessWidget {
  final ChatState? chatState;
  final void Function(DynamicWallpaperDefinition definition) onSelect;

  const WallpaperGalleryGrid({super.key, required this.chatState, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final definitions = DynamicWallpaperRegistry.all;

    return Obx(() {
      final selectedId = chatState?.wallpaperType.value == ChatWallpaperType.dynamic
          ? chatState?.dynamicWallpaperId.value
          : null;

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: definitions.length,
        itemBuilder: (context, index) {
          final definition = definitions[index];
          return _GalleryTile(
            definition: definition,
            selected: definition.id == selectedId,
            onTap: () => onSelect(definition),
          );
        },
      );
    });
  }
}

class _GalleryTile extends StatelessWidget {
  final DynamicWallpaperDefinition definition;
  final bool selected;
  final VoidCallback onTap;

  const _GalleryTile({required this.definition, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? context.theme.colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: context.theme.colorScheme.surfaceContainerHighest,
              child: DynamicWallpaperView(wallpaperId: definition.id, config: null),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(definition.icon, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        definition.displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: context.theme.colorScheme.primary, shape: BoxShape.circle),
                  child: Icon(Icons.check, size: 14, color: context.theme.colorScheme.onPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
