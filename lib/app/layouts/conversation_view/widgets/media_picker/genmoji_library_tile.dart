import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_actions.dart';
import 'package:bluebubbles/models/genmoji.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// One Genmoji from the Mac's library, drawn from the on-disk thumbnail cache.
///
/// Shows a placeholder until `GenmojiLibraryService` has the thumbnail, a ring and check while
/// the Genmoji is in the draft, and a spinner while its send-size image downloads. Used by the
/// mobile attachment picker's Genmoji grid and the desktop Genmoji popover.
class GenmojiLibraryTile extends StatelessWidget {
  const GenmojiLibraryTile({
    super.key,
    required this.entry,
    required this.controller,
    required this.onTap,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.padding = const EdgeInsets.all(10),
  });

  final GenmojiLibraryEntry entry;
  final ConversationViewController controller;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Right-click, for a desktop context menu.
  final GestureTapUpCallback? onSecondaryTapUp;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Obx(() {
      final id = entry.identifier;
      final cached = GenmojiLibrarySvc.cachedThumbnails.contains(id);
      final attaching = AttachmentActions.attachingGenmoji.contains(id);
      final selected = AttachmentActions.isGenmojiAttached(controller, entry);

      return Semantics(
        button: true,
        selected: selected,
        label: entry.description.isEmpty ? "Genmoji" : entry.description,
        child: Material(
          color: selected ? scheme.primary.withValues(alpha: 0.14) : scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: selected ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: attaching ? null : onTap,
            onLongPress: onLongPress,
            onSecondaryTapUp: onSecondaryTapUp,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: padding,
                  child: cached
                      ? Image.file(
                          GenmojiLibrarySvc.thumbnailFile(id),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => _placeholder(scheme),
                        )
                      : _placeholder(scheme),
                ),
                if (attaching)
                  ColoredBox(
                    color: scheme.surface.withValues(alpha: 0.5),
                    child: const Center(child: CupertinoActivityIndicator()),
                  ),
                if (selected)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.check_rounded, size: 14, color: scheme.onPrimary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _placeholder(ColorScheme scheme) =>
      Center(child: Icon(Icons.emoji_emotions_outlined, size: 28, color: scheme.outline.withValues(alpha: 0.4)));
}

/// The "make a new one" tile that leads the Genmoji grid, styled to stand out from the
/// library around it.
class GenmojiCreateTile extends StatelessWidget {
  const GenmojiCreateTile({super.key, required this.onTap, this.compact = false});

  final VoidCallback onTap;

  /// Icon only, for the desktop popover's smaller cells.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return Semantics(
      button: true,
      label: "Create a new Genmoji",
      child: Material(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [scheme.primary, scheme.tertiary],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary, size: compact ? 24 : 30),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Text("New", style: context.theme.textTheme.labelLarge!.copyWith(color: scheme.onPrimary)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
