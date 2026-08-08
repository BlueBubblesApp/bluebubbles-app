import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';

/// Tappable "X Photos" / "X Items" header for media collection layouts.
///
/// Callers gate visibility (e.g. iOS skin only). Tap opens the full collection grid.
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
