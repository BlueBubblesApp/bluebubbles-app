import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

/// A small anchored popup menu with a scale/fade entrance animation, used for
/// the Material/Samsung skin's dropdown-style menus (main conversation list
/// header avatar menu, contact tile actions, settings dropdowns, etc).
/// Renders via an [OverlayEntry] positioned relative to [trigger] using a
/// [LayerLink].
///
/// Anchor side (left/right) and vertical direction (above/below) are picked
/// dynamically each time the menu opens, based on how much screen space
/// surrounds the trigger — so a trigger near the left edge or bottom of the
/// screen still gets a fully on-screen menu instead of clipping.
class AnimatedDropdownMenu extends StatefulWidget {
  const AnimatedDropdownMenu({
    super.key,
    required this.trigger,
    required this.menuBuilder,
    required this.menuWidth,
    this.gap = 8,
  });

  /// Builds the tappable trigger widget. Call [showMenu] to open the popup.
  final Widget Function(BuildContext context, VoidCallback showMenu) trigger;

  /// Builds the popup content. Call [hideMenu] to dismiss it (e.g. after an
  /// item is tapped).
  final Widget Function(BuildContext context, Future<void> Function() hideMenu) menuBuilder;

  /// Width of the card built by [menuBuilder] — pass the same value given to
  /// the inner [DropdownMenuCard.width]. Used to decide which side of the
  /// trigger the menu has room to grow toward.
  final double menuWidth;

  /// Gap kept between the trigger and the menu.
  final double gap;

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

  Alignment _targetAnchor = Alignment.bottomRight;
  Alignment _followerAnchor = Alignment.topRight;
  Offset _offset = const Offset(0, 8);

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _animationController.dispose();
    super.dispose();
  }

  /// Picks which corner of the trigger the menu grows from, based on the
  /// space actually available around the trigger on-screen.
  void _computeAnchors() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final triggerSize = renderBox.size;
    final triggerTopLeft = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.sizeOf(context);

    // Growing left from the trigger's right edge is the default look — flip
    // to growing right from the trigger's left edge if that would clip.
    final spaceToGrowLeft = triggerTopLeft.dx + triggerSize.width;
    final growLeft = spaceToGrowLeft >= widget.menuWidth;

    // Prefer opening below; flip above when there's more room there.
    final spaceBelow = screenSize.height - (triggerTopLeft.dy + triggerSize.height);
    final spaceAbove = triggerTopLeft.dy;
    final openBelow = spaceBelow >= spaceAbove;

    _targetAnchor = Alignment(growLeft ? 1.0 : -1.0, openBelow ? 1.0 : -1.0);
    _followerAnchor = Alignment(growLeft ? 1.0 : -1.0, openBelow ? -1.0 : 1.0);
    _offset = Offset(0, openBelow ? widget.gap : -widget.gap);
  }

  void _showMenu() {
    if (_overlayEntry != null) {
      _hideMenu();
      return;
    }
    _computeAnchors();
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
              targetAnchor: _targetAnchor,
              followerAnchor: _followerAnchor,
              offset: _offset,
              child: ScaleTransition(
                scale: _scaleAnimation,
                alignment: _followerAnchor,
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
