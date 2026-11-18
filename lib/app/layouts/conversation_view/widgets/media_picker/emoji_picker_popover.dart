import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/composer_popover.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' hide Emoji;
import 'package:flutter/cupertino.dart';
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
    final iOS = SettingsSvc.settings.skin.value == Skins.iOS;
    final outline = context.theme.colorScheme.outline;
    return LayoutBuilder(
      builder: (context, constraints) => Theme(
        data: context.theme.copyWith(canvasColor: Colors.transparent),
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) => _insert(emoji.emoji),
          config: Config(
            height: constraints.maxHeight,
            emojiSet: (_) => emojiSetEnglish,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              emojiSizeMax: 28,
              backgroundColor: Colors.transparent,
              columns: (constraints.maxWidth ~/ 44).clamp(5, 12),
              noRecents: Text("No Recents", style: context.textTheme.titleMedium!.copyWith(color: outline)),
            ),
            viewOrderConfig: const ViewOrderConfig(
              top: EmojiPickerItem.categoryBar,
              middle: EmojiPickerItem.emojiView,
              bottom: EmojiPickerItem.searchBar,
            ),
            skinToneConfig: const SkinToneConfig(enabled: false),
            categoryViewConfig: const CategoryViewConfig(
              backgroundColor: Colors.transparent,
              dividerColor: Colors.transparent,
            ),
            bottomActionBarConfig: BottomActionBarConfig(
              customBottomActionBar: (config, state, showSearchView) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: showSearchView,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(iOS ? CupertinoIcons.search : Icons.search, color: outline),
                        const SizedBox(width: 8),
                        Text("Search...", style: context.theme.textTheme.bodyLarge!.copyWith(color: outline)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            searchViewConfig: SearchViewConfig(backgroundColor: Colors.transparent, buttonIconColor: outline),
          ),
        ),
      ),
    );
  }
}
