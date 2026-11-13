import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_actions.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/buttons/text_field_button.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The desktop composer's `+` menu: every supported [TextFieldButton] that isn't already in
/// the composer row ([inRow]), so the Text Field Buttons setting decides what lives where.
///
/// Wraps the `+` button: [builder] gets a callback that opens or closes the menu. The menu
/// opens above the button when there's no room below (always, in the composer) and scrolls
/// when the window is too short for it.
class DesktopAttachmentMenu extends StatefulWidget {
  const DesktopAttachmentMenu({super.key, required this.controller, required this.builder, required this.inRow});

  final ConversationViewController controller;
  final List<TextFieldButton> inRow;
  final Widget Function(BuildContext context, VoidCallback toggle) builder;

  @override
  State<DesktopAttachmentMenu> createState() => _DesktopAttachmentMenuState();
}

/// Also drawn by the Text Field Buttons settings preview of this menu
const Map<TextFieldButton, (IconData, Color)> desktopMenuIcons = {
  TextFieldButton.Files: (Icons.folder_rounded, Color(0xFF007AFF)),
  TextFieldButton.Genmoji: (Icons.add_reaction_rounded, Color(0xFFFF2D55)),
  TextFieldButton.Handwritten: (Icons.draw_rounded, Color(0xFFAF52DE)),
  TextFieldButton.Schedule: (Icons.schedule_rounded, Color(0xFFFF9500)),
  TextFieldButton.Location: (Icons.location_on_rounded, Color(0xFF32ADE6)),
  TextFieldButton.Gif: (Icons.gif_box_rounded, Color(0xFF34C759)),
  TextFieldButton.Emoji: (Icons.emoji_emotions_rounded, Color(0xFFFFCC00)),
};

class _DesktopAttachmentMenuState extends State<DesktopAttachmentMenu> {
  final MenuController _menu = MenuController();

  ConversationViewController get controller => widget.controller;

  /// Runs [action] once the menu has closed, so a dialog it opens isn't fighting the menu's
  /// focus scope.
  void _run(FutureOr<void> Function() action) {
    _menu.close();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await action();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outline.withValues(alpha: 0.15)),
          ),
        ),
      ),
      menuChildren: [
        for (final b in TextFieldButton.values.platformSupportedButtons.whereNot(widget.inRow.contains))
          _item(
            icon: desktopMenuIcons[b]!.$1,
            color: desktopMenuIcons[b]!.$2,
            label: b.label,
            onPressed: () => _run(() => AttachmentActions.run(b, context, controller)),
          ),
      ],
      builder: (context, menu, _) => widget.builder(context, () => menu.isOpen ? menu.close() : menu.open()),
    );
  }

  Widget _item({required IconData icon, required Color color, required String label, required VoidCallback onPressed}) {
    return MenuItemButton(
      onPressed: onPressed,
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(220, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      leadingIcon: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(icon, size: 17, color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(label, style: context.theme.textTheme.bodyLarge),
      ),
    );
  }
}
