import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';

/// Label row above an iOS media collection stack (icon + "X Items").
class CollectionTitle extends StatefulWidget {
  const CollectionTitle({
    super.key,
    required this.attachments,
    required this.isFromMe,
    required this.onTap,
  });

  final List<Attachment> attachments;
  final bool isFromMe;
  final VoidCallback? onTap;

  static String labelFor(List<Attachment> attachments) {
    final photoCount = attachments.where((a) => a.mimeStart == 'image').length;
    final videoCount = attachments.where((a) => a.mimeStart == 'video').length;
    if (photoCount > 0 && videoCount > 0) {
      return '${photoCount + videoCount} Items';
    }
    if (videoCount > 0) {
      return '$videoCount ${videoCount == 1 ? 'Video' : 'Videos'}';
    }
    return '$photoCount ${photoCount == 1 ? 'Photo' : 'Photos'}';
  }

  String get label => labelFor(attachments);

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
        onTap: kIsDesktop ? widget.onTap : null,
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
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
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
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 3),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
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
