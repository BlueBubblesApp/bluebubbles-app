import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/media_collection.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// iOS-skin chrome shared by the stack and grid: a [CollectionTitle] above [child], aligned to the author's side.
///
/// On Material / Samsung this returns [child] unchanged, so layouts don't each re-check the skin.
class CollectionTitledLayout extends StatelessWidget {
  const CollectionTitledLayout({
    super.key,
    required this.collection,
    required this.isFromMe,
    required this.child,
    this.spacing = const SizedBox(height: 4),
  });

  final MediaCollection collection;
  final bool isFromMe;
  final Widget child;

  /// Gap between the title and [child].
  final Widget spacing;

  @override
  Widget build(BuildContext context) {
    if (!context.iOS) return child;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        CollectionTitle(
          label: collection.title,
          onTap: () => collection.openGallery(context),
        ),
        spacing,
        child,
      ],
    );
  }
}

/// Tappable "X Photos" / "X Items" header for media collection layouts.
///
/// Usually placed via [CollectionTitledLayout]. Tap opens the full collection grid.
class CollectionTitle extends StatefulWidget {
  const CollectionTitle({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<CollectionTitle> createState() => _CollectionTitleState();
}

class _CollectionTitleState extends State<CollectionTitle> {
  bool _labelHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: kIsDesktop ? (_) => setState(() => _labelHovered = true) : null,
      onExit: kIsDesktop ? (_) => setState(() => _labelHovered = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -6,
              right: -6,
              top: -2,
              bottom: -2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _labelHovered
                      ? context.theme.colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.grid_view_rounded,
                  size: 10,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 3),
                Text(
                  widget.label,
                  style: context.theme.textTheme.labelSmall?.copyWith(
                        color: context.theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
