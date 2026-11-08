import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_actions.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/genmoji_library_popover.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The desktop composer's `+` menu: a popup list of everything the mobile attachment picker
/// offers that desktop can do — Files, Photos & Videos, Genmoji (v2 server), Handwritten,
/// Schedule and Location (not on Linux).
///
/// Wraps the `+` button: [builder] gets a callback that opens or closes the menu. The menu
/// opens above the button when there's no room below (always, in the composer) and scrolls
/// when the window is too short for it.
class DesktopAttachmentMenu extends StatefulWidget {
  const DesktopAttachmentMenu({super.key, required this.controller, required this.builder});

  final ConversationViewController controller;
  final Widget Function(BuildContext context, VoidCallback toggle) builder;

  @override
  State<DesktopAttachmentMenu> createState() => _DesktopAttachmentMenuState();
}

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
        _item(
          icon: Icons.folder_rounded,
          color: const Color(0xFF007AFF),
          label: "Files",
          onPressed: () => _run(() => AttachmentActions.pickFiles(controller)),
        ),
        _item(
          icon: Icons.photo_library_rounded,
          color: const Color(0xFF5856D6),
          label: "Photos & Videos",
          onPressed: () => _run(() => AttachmentActions.pickFiles(controller, type: FileType.media)),
        ),
        // v2 (Swift) server only.
        if (SettingsSvc.getServerDetails().supportsGenmoji)
          _item(
            icon: Icons.add_reaction_rounded,
            color: const Color(0xFFFF2D55),
            label: "Genmoji",
            onPressed: () => _run(() => showGenmojiLibraryPopover(context, controller)),
          ),
        _item(
          icon: Icons.draw_rounded,
          color: const Color(0xFFAF52DE),
          label: "Handwritten",
          onPressed: () => _run(() => AttachmentActions.handwritten(context, controller)),
        ),
        _item(
          icon: Icons.schedule_rounded,
          color: const Color(0xFFFF9500),
          label: "Schedule",
          onPressed: () => _run(() => AttachmentActions.schedule(context, controller)),
        ),
        if (AttachmentActions.supportsLocation)
          _item(
            icon: Icons.location_on_rounded,
            color: const Color(0xFF32ADE6),
            label: "Location",
            onPressed: () => _run(() => AttachmentActions.shareLocation(controller)),
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
