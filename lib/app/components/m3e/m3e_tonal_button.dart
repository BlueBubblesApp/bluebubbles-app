import 'package:bluebubbles/app/components/m3e/m3e_motion.dart';
import 'package:bluebubbles/app/components/m3e/m3e_shapes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Quick-action button for the expressive hero row. Corner-morphs toward [M3EShapes.md]
/// while pressed as a stand-in for true M3E shape morphing.
class M3ETonalButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;

  const M3ETonalButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(M3EShapes.xl)),
  });

  @override
  State<M3ETonalButton> createState() => _M3ETonalButtonState();
}

class _M3ETonalButtonState extends State<M3ETonalButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    const pressedRadius = BorderRadius.all(Radius.circular(M3EShapes.md));

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: M3EMotion.spatialFast.duration,
        curve: M3EMotion.spatialFast.curve,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: _pressed ? pressedRadius : widget.borderRadius,
        ),
        constraints: const BoxConstraints(minHeight: 56),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            onLongPress: widget.onLongPress,
            splashFactory: context.theme.splashFactory,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: colorScheme.onSecondaryContainer),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
