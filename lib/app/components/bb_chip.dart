import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A custom BlueBubbles chip widget that provides a consistent design pattern
/// for filter chips throughout the app. Supports both deletable and selectable modes.
class BBChip extends StatelessWidget {
  final Widget label;
  final Widget? avatar;
  final bool tapEnabled;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeleted;
  final bool showCheckmark;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Color? checkmarkColor;

  /// Background when [selected] is true. Defaults to the theme's chip default
  /// (a subtle tint) — pass an explicit color for a more prominent highlight.
  final Color? selectedColor;

  /// Background when [selected] is false. Defaults to the theme's chip default.
  final Color? backgroundColor;

  final TextStyle? labelStyle;

  /// Corner radius override — defaults to `BorderRadius.circular(20)`.
  final BorderRadius? borderRadius;

  const BBChip({
    super.key,
    required this.label,
    this.avatar,
    this.tapEnabled = true,
    this.onPressed,
    this.onLongPress,
    this.onDeleted,
    this.showCheckmark = false,
    this.selected = false,
    this.onSelected,
    this.checkmarkColor,
    this.selectedColor,
    this.backgroundColor,
    this.labelStyle,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final chip = RawChip(
      tapEnabled: tapEnabled,
      deleteIcon: onDeleted != null ? const Icon(Icons.close, size: 16) : null,
      side: BorderSide(
        color: selected
            ? (selectedColor ?? context.theme.colorScheme.primary)
            : context.theme.colorScheme.outline.withValues(alpha: 0.1),
      ),
      shape: RoundedRectangleBorder(borderRadius: borderRadius ?? BorderRadius.circular(20)),
      avatar: avatar,
      label: label,
      labelStyle: labelStyle,
      onDeleted: onDeleted,
      onPressed: onPressed,
      showCheckmark: showCheckmark,
      selected: selected,
      onSelected: onSelected,
      checkmarkColor: checkmarkColor,
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
    );

    if (onLongPress == null) return chip;

    return GestureDetector(
      onLongPress: onLongPress,
      child: chip,
    );
  }
}
