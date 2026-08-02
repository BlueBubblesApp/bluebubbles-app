import 'package:bluebubbles/app/components/m3e/m3e_motion.dart';
import 'package:bluebubbles/app/components/m3e/m3e_shapes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Quick-action button for the expressive hero row. Corner-morphs toward [M3EShapes.md]
/// while pressed as a stand-in for true M3E shape morphing.
class M3ETonalButton extends StatefulWidget {
  final IconData icon;
  final String label;

  /// Null disables the button: no tap, no ripple, no long-press, dimmed
  /// content, and `enabled: false` to the semantics tree so a screen reader
  /// stops announcing it as actionable. Pass null rather than an empty
  /// callback for a busy/unavailable state.
  final VoidCallback? onPressed;

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

    final enabled = widget.onPressed != null;
    // M3's disabled recipe: the container and its content keep their own hues
    // and drop to the standard opacities, rather than switching to a different
    // colour role.
    final containerColor =
        enabled ? colorScheme.secondaryContainer : colorScheme.onSurface.withValues(alpha: 0.12);
    final contentColor =
        enabled ? colorScheme.onSecondaryContainer : colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: AnimatedContainer(
          duration: M3EMotion.spatialFast.duration,
          curve: M3EMotion.spatialFast.curve,
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: _pressed ? pressedRadius : widget.borderRadius,
          ),
          constraints: const BoxConstraints(minHeight: 56),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              // Null on both leaves InkWell inert — no splash, no hover, no
              // focus node — which is what "disabled" should mean visually too.
              onTap: widget.onPressed,
              onLongPress: enabled ? widget.onLongPress : null,
              splashFactory: context.theme.splashFactory,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: contentColor),
                    const SizedBox(height: 4),
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.labelMedium?.copyWith(color: contentColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
