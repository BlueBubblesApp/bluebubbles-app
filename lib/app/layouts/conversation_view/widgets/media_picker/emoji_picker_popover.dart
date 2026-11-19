import 'package:bluebubbles/app/components/bb_emoji_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/composer_popover.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const double _width = 400;
const double _height = 420;

/// The desktop composer's Emoji button: an emoji picker as a popover above [anchorContext]. Each pick goes into the
/// field being typed in (a message being edited, else the composer) at its cursor; the popover stays open for more.
Future<void> showEmojiPickerPopover(BuildContext anchorContext, ConversationViewController controller) async {
  await showComposerPopover(
    anchorContext,
    controller,
    width: _width,
    height: _height,
    builder: (context) => ComposerPopoverCard(child: _EmojiPickerPanel(controller: controller)),
  );
  (controller.editing.lastOrNull?.controller.focusNode ?? controller.lastFocusedNode).requestFocus();
}

class _EmojiPickerPanel extends StatelessWidget {
  const _EmojiPickerPanel({required this.controller});

  final ConversationViewController controller;

  void _insert(String emoji) {
    final field = controller.editing.lastOrNull?.controller ?? controller.lastFocusedTextController;
    final text = field.text;
    final selection = field.selection.isValid ? field.selection : TextSelection.collapsed(offset: text.length);
    field.text = text.substring(0, selection.start) + emoji + text.substring(selection.end);
    field.selection = TextSelection.collapsed(offset: selection.start + emoji.length);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Theme(
        data: context.theme.copyWith(canvasColor: Colors.transparent),
        child: buildBBEmojiPicker(
          context,
          height: constraints.maxHeight,
          // The popover card draws the surface
          background: Colors.transparent,
          columns: (constraints.maxWidth ~/ 44).clamp(5, 12),
          onPicked: _insert,
        ),
      ),
    );
  }
}
