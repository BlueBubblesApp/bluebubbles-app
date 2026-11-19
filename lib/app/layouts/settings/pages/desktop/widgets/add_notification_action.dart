import 'dart:io';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/widgets/emoji_tapback_picker.dart';
import 'package:bluebubbles/app/components/animated_dropdown_menu.dart';
import 'package:bluebubbles/app/layouts/settings/pages/desktop/widgets/grayed_out.dart';
import 'package:bluebubbles/app/layouts/settings/pages/desktop/widgets/notification_action_button.dart';
import 'package:bluebubbles/app/layouts/settings/pages/desktop/widgets/toast_preview_theme.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The Add Action tile. Opens a panel of the actions it can add, each drawn as the button it would be: the tapbacks
/// and Mark Read not already chosen, and a custom emoji.
class AddNotificationAction extends StatelessWidget {
  const AddNotificationAction({super.key, required this.actions, required this.toast, this.fullMessage});
  final List<String> actions;
  final ToastPreviewTheme toast;

  /// Set once the notification has no room for another action: the tile grays out and this says why
  final String? fullMessage;

  static const double _padding = 8;
  static const double _gap = 6;
  static const int _perRow = 4;

  void _add(String action) {
    NotificationActionButton.justAdded = action;
    SettingsSvc.settings.setNotificationActions([...actions, action]);
  }

  @override
  Widget build(BuildContext context) {
    final full = fullMessage != null;
    // The panel's buttons at the preview's size on Windows, and the picker's on Linux
    final size = min(NavigationSvc.width(context) / 2, 400) - 40;
    final height = Platform.isWindows ? size * 0.13 : 56.0;
    final tileWidth = Platform.isWindows ? height * 2.2 : 90.0;
    final glyphSize = Platform.isWindows ? size * 16 / 364 : 22.0;
    final textStyle = context.textTheme.bodyMedium!.copyWith(
      fontSize: Platform.isWindows ? size * 0.037 : 16,
      color: toast.text,
    );
    final options = <(Widget, Future<void> Function())>[
      if (!actions.contains("Mark Read"))
        (Text("Mark Read", style: textStyle, textAlign: TextAlign.center), () async => _add("Mark Read")),
      for (final type in ReactionTypes.toList())
        if (!actions.contains(type)) (ActionGlyph(type, size: glyphSize), () async => _add(type)),
      if (SettingsSvc.serverDetails.supportsEmojiTapbacks)
        (
          Icon(Icons.add_reaction_outlined, size: glyphSize * 1.15, color: toast.text),
          () async {
            final emoji = (await showEmojiTapbackPicker(context) as EmojiTapbackPick?)?.emoji;
            if (emoji != null && !actions.contains(emoji)) _add(emoji);
          },
        ),
    ];
    final columns = options.length.clamp(1, _perRow);
    final menuWidth = columns * tileWidth + (columns - 1) * _gap + 2 * _padding + 2;
    return AnimatedDropdownMenu(
      menuWidth: menuWidth,
      trigger: (context, showMenu) => GrayedOut(
        grayed: full,
        child: SettingsTile(
          title: "Add Action",
          subtitle:
              fullMessage ??
              (SettingsSvc.serverDetails.supportsEmojiTapbacks
                  ? "A tapback, Mark Read, or an emoji"
                  : "A tapback or Mark Read"),
          onTap: options.isEmpty ? null : showMenu,
          leading: const SettingsLeadingIcon(
            iosIcon: CupertinoIcons.add,
            materialIcon: Icons.add,
            containerColor: Colors.green,
          ),
        ),
      ),
      menuBuilder: (context, hideMenu) => Material(
        elevation: 8,
        color: toast.background,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: menuWidth,
          padding: const EdgeInsets.all(_padding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: toast.border),
          ),
          child: Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final (child, onPick) in options)
                _PickerTile(
                  toast: toast,
                  width: tileWidth,
                  height: height,
                  onTap: () async {
                    await hideMenu();
                    if (context.mounted) await onPick();
                  },
                  child: child,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatefulWidget {
  const _PickerTile({
    required this.toast,
    required this.width,
    required this.height,
    required this.onTap,
    required this.child,
  });
  final ToastPreviewTheme toast;
  final double width;
  final double height;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PickerTile> createState() => _PickerTileState();
}

class _PickerTileState extends State<_PickerTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: widget.toast.border),
          color: _hovered ? widget.toast.border : widget.toast.button,
        ),
        child: Center(child: widget.child),
      ),
    ),
  );
}
