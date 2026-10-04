import 'package:bluebubbles/app/layouts/settings/pages/theming/theme_studio/theme_studio_panel.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// A full-width row that shows a color swatch, its label, hex value, and
/// an explicit Edit button.  If the color has a paired "on" color, both are
/// shown side-by-side.
class ColorEditorTile extends StatelessWidget {
  const ColorEditorTile({
    super.key,
    required this.mainKey,
    required this.onKey,
    required this.mainColor,
    required this.onColor,
    required this.editable,
    required this.controller,
  });

  final String mainKey;
  final String? onKey;
  final Color mainColor;
  final Color? onColor;
  final bool editable;
  final ThemeStudioController controller;

  String _hexOf(Color c) => '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // ── Color swatches ────────────────────────────────────────────────
          _ColorSwatch(
            color: mainColor,
            size: 44,
            borderRadius: onColor != null ? 8 : 10,
          ),
          if (onColor != null) ...[
            const SizedBox(width: 6),
            _ColorSwatch(color: onColor!, size: 36, borderRadius: 8),
          ],

          const SizedBox(width: 14),

          // ── Labels ────────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mainKey + (onKey != null ? ' / $onKey' : ''),
                  style: context.theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onLongPress: () async {
                    await Clipboard.setData(ClipboardData(text: _hexOf(mainColor)));
                    showCopiedToast("Copied ${_hexOf(mainColor)}");
                  },
                  child: Text(
                    _hexOf(mainColor) + (onColor != null ? '  ·  ${_hexOf(onColor!)}' : ''),
                    style: context.theme.textTheme.labelSmall?.copyWith(
                      color: context.theme.colorScheme.outline,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Edit buttons ──────────────────────────────────────────────────
          if (editable) ...[
            _EditButton(
              tooltip: 'Edit $mainKey',
              onPressed: () => _editColor(context, mainKey, mainColor),
            ),
            if (onKey != null) ...[
              const SizedBox(width: 4),
              _EditButton(
                tooltip: 'Edit $onKey',
                onPressed: () => _editColor(context, onKey!, onColor ?? mainColor),
              ),
            ],
          ] else ...[
            Tooltip(
              message: ThemeSvc.isAnyMaterialYouSelected ? "Material You is active" : "Select a custom theme to edit",
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: context.theme.colorScheme.outline,
              ),
            ),
          ],

          // ── Info button ───────────────────────────────────────────────────
          const SizedBox(width: 4),
          _InfoButton(colorKey: mainKey, onKey: onKey),
        ],
      ),
    );
  }

  Future<void> _editColor(BuildContext context, String key, Color current) async {
    final picked = await showColorPickerDialog(context, current);
    if (picked != null) {
      controller.updateColorKey(context, key, picked);
    }
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.size, required this.borderRadius});
  final Color color;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: context.theme.colorScheme.outline.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.tooltip, required this.onPressed});
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.edit_outlined),
        iconSize: 18,
        color: context.theme.colorScheme.primary,
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.all(6),
        ),
      ),
    );
  }
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.colorKey, required this.onKey});
  final String colorKey;
  final String? onKey;

  @override
  Widget build(BuildContext context) {
    final desc = ThemeStruct.colorDescriptions[colorKey];
    if (desc == null) return const SizedBox.shrink();
    return Tooltip(
      message: 'About this color',
      child: IconButton(
        onPressed: () => _showInfo(context, desc),
        icon: const Icon(Icons.info_outline),
        iconSize: 18,
        color: context.theme.colorScheme.onSurfaceVariant,
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.all(6),
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, String desc) {
    final onDesc = onKey != null ? ThemeStruct.colorDescriptions[onKey!] : null;
    showBBDialog(
      context: context,
      title: '$colorKey${onKey != null ? ' / $onKey' : ''}',
      content: SingleChildScrollView(
        child: Text(
          '$desc${onDesc != null ? '\n\n$onDesc' : ''}',
          style: context.theme.textTheme.bodyMedium,
        ),
      ),
      actions: [
        BBDialogAction(
          text: "OK",
          isDefault: true,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }
}

// ─── Shared color picker dialog ────────────────────────────────────────────────

Future<Color?> showColorPickerDialog(BuildContext context, Color initial) async {
  Color selected = initial;
  return showBBDialog<Color>(
    context: context,
    content: ColorPicker(
      color: selected,
      onColorChanged: (c) => selected = c,
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Choose a Color', style: context.theme.textTheme.titleLarge),
      ),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 0,
      wheelDiameter: 165,
      enableOpacity: false,
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: const {ColorPickerType.wheel: true},
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(parseShortHexCode: true),
      actionButtons: const ColorPickerActionButtons(dialogActionButtons: false),
    ),
    actions: [
      BBDialogAction(
        text: 'CANCEL',
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
      ),
      BBDialogAction(
        text: 'SAVE',
        isDefault: true,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(selected),
      ),
    ],
  );
}
