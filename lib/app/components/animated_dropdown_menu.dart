import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

/// A small anchored popup menu with a scale/fade entrance animation, used for
/// the Material/Samsung skin's dropdown-style menus (main conversation list
/// header avatar menu, contact tile actions, etc). Renders via an
/// [OverlayEntry] positioned relative to [trigger] using a [LayerLink].
class AnimatedDropdownMenu extends StatefulWidget {
  const AnimatedDropdownMenu({
    super.key,
    required this.trigger,
    required this.menuBuilder,
    this.anchor = Alignment.bottomRight,
    this.followerAnchor = Alignment.topRight,
    this.offset = const Offset(0, 8),
  });

  /// Builds the tappable trigger widget. Call [showMenu] to open the popup.
  final Widget Function(BuildContext context, VoidCallback showMenu) trigger;

  /// Builds the popup content. Call [hideMenu] to dismiss it (e.g. after an
  /// item is tapped).
  final Widget Function(BuildContext context, Future<void> Function() hideMenu) menuBuilder;

  final Alignment anchor;
  final Alignment followerAnchor;
  final Offset offset;

  @override
  State<AnimatedDropdownMenu> createState() => _AnimatedDropdownMenuState();
}

class _AnimatedDropdownMenuState extends State<AnimatedDropdownMenu> with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    reverseDuration: const Duration(milliseconds: 250),
  );
  late final Animation<double> _scaleAnimation =
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack);
  late final Animation<double> _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _animationController.dispose();
    super.dispose();
  }

  void _showMenu() {
    if (_overlayEntry != null) {
      _hideMenu();
      return;
    }
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
  }

  Future<void> _hideMenu() async {
    await _animationController.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _buildOverlayEntry() {
    return OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideMenu,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: widget.anchor,
              followerAnchor: widget.followerAnchor,
              offset: widget.offset,
              child: ScaleTransition(
                scale: _scaleAnimation,
                alignment: widget.followerAnchor,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: widget.menuBuilder(overlayContext, _hideMenu),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: widget.trigger(context, _showMenu),
    );
  }
}

/// A card matching the Material/Samsung dropdown menu's styling — use as the
/// root of [AnimatedDropdownMenu.menuBuilder].
class DropdownMenuCard extends StatelessWidget {
  const DropdownMenuCard({super.key, required this.children, this.width = 240});

  final List<Widget> children;
  final double width;

  @override
  Widget build(BuildContext context) {
    final windowEffect = SettingsSvc.settings.windowEffect.value;
    final cardColor = context.theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: windowEffect != WindowEffect.disabled ? 0.95 : 1.0);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: cardColor,
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A single row in a [DropdownMenuCard] — icon, label, and tap handler.
class MenuItemRow extends StatelessWidget {
  const MenuItemRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Overrides the default icon color — e.g. to highlight when a toggleable
  /// action (like "Filter Chats") is currently active.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: iconColor ?? context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: context.theme.textTheme.bodyLarge?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
