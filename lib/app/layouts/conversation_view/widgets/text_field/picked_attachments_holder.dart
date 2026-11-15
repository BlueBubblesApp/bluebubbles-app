import 'dart:math';

import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_view/dialogs/custom_mention_dialog.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/picked_attachment.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PickedAttachmentsHolder extends StatefulWidget {
  const PickedAttachmentsHolder({
    super.key,
    required this.textController,
    required this.controller,
    this.initialAttachments = const [],
  });

  final ConversationViewController? controller;
  final TextEditingController textController;
  final List<PlatformFile> initialAttachments;

  @override
  State<StatefulWidget> createState() => _PickedAttachmentsHolderState();
}

class _PickedAttachmentsHolderState extends State<PickedAttachmentsHolder> with ThemeHelpers {
  // Cache platform check to avoid repeated lookups
  late final bool _isIOS = SettingsSvc.settings.skin.value == Skins.iOS;

  List<PlatformFile> get pickedAttachments =>
      widget.controller != null ? widget.controller!.pickedAttachments : widget.initialAttachments;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Attachments list - isolated Obx
        Obx(() {
          if (pickedAttachments.isEmpty) {
            return const SizedBox.shrink();
          }

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: _isIOS ? 150 : 100,
              minHeight: _isIOS ? 150 : 100,
            ),
            child: Padding(
              padding: _isIOS ? EdgeInsets.zero : const EdgeInsets.only(left: 7.5, right: 7.5),
              child: CustomScrollView(
                physics: ThemeSwitcher.getScrollPhysics(),
                scrollDirection: Axis.horizontal,
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return PickedAttachment(
                          key: ValueKey(pickedAttachments[index].name),
                          data: pickedAttachments[index],
                          controller: widget.controller,
                          onRemove: (file) {
                            if (widget.controller == null) {
                              pickedAttachments.removeAt(index);
                              setState(() {});
                            }
                          },
                          pickedAttachmentIndex: index,
                        );
                      },
                      childCount: pickedAttachments.length,
                    ),
                  )
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// The emoji and mention suggestions, floating above the top of the composer, where this sits, rather than in it.
/// The composer animates to its content's size, so suggestions taking room in it would grow and shrink it (and
/// resize the message list) each time they came and went, which typing a name without "@" does word by word.
class ComposerSuggestions extends StatefulWidget {
  const ComposerSuggestions({super.key, required this.controller});

  final ConversationViewController controller;

  @override
  State<ComposerSuggestions> createState() => _ComposerSuggestionsState();
}

class _ComposerSuggestionsState extends State<ComposerSuggestions> {
  late final bool _isIOS = SettingsSvc.settings.skin.value == Skins.iOS;

  // Always shown: what it shows (nothing, most of the time) is up to the Obx inside
  final _portal = OverlayPortalController()..show();

  Future<void> _selectMention(int index, bool custom) async {
    final controller = widget.controller;
    final mention = controller.mentionMatches[index];
    String? name;
    if (custom) {
      name = await showCustomMentionDialog(context, mention);
      if (isNullOrEmpty(name) || !mounted) return;
    }
    controller.mentionSelectedIndex.value = 0;
    controller.textController.addMention(mention, name: name);
    controller.mentionMatches.clear();
    controller.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) {
        final origin = MatrixUtils.transformPoint(info.childPaintTransform, Offset.zero);
        return Stack(
          children: [
            Positioned(
              left: origin.dx,
              width: info.childSize.width,
              bottom: info.overlaySize.height - origin.dy,
              // In the field's tap group, so picking one doesn't count as tapping away from the field
              child: TextFieldTapRegion(
                child: Obx(() {
                  if (widget.controller.emojiMatches.isNotEmpty) {
                    return _EmojiSuggestions(controller: widget.controller, isIOS: _isIOS);
                  }
                  if (widget.controller.mentionMatches.isNotEmpty) {
                    return _MentionSuggestions(
                      controller: widget.controller,
                      isIOS: _isIOS,
                      onSelect: _selectMention,
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ),
            ),
          ],
        );
      },
      // The anchor: the composer's full width, taking no height
      child: const SizedBox(width: double.infinity, height: 0),
    );
  }
}

/// Extracted emoji suggestions to reduce parent rebuild scope
class _EmojiSuggestions extends StatelessWidget {
  const _EmojiSuggestions({
    required this.controller,
    required this.isIOS,
  });

  final ConversationViewController controller;
  final bool isIOS;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: min(controller.emojiMatches.length * 60, 180)),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Container(
          decoration: BoxDecoration(
            border: isIOS
                ? null
                : Border.fromBorderSide(
                    BorderSide(color: context.theme.colorScheme.surface, strokeAlign: BorderSide.strokeAlignOutside)),
            borderRadius: BorderRadius.circular(20),
            color: context.theme.colorScheme.surfaceContainerHighest,
          ),
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            radius: const Radius.circular(4),
            controller: controller.emojiScrollController,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 0),
              controller: controller.emojiScrollController,
              physics: ThemeSwitcher.getScrollPhysics(),
              shrinkWrap: true,
              findChildIndexCallback: (key) =>
                  findChildIndexByKey(controller.emojiMatches, key, (item) => item.unified),
              itemBuilder: (BuildContext context, int index) {
                final emoji = controller.emojiMatches[index];
                return Material(
                  key: ValueKey(emoji.unified),
                  color: Colors.transparent,
                  child: InkWell(
                    onTapDown: (details) {
                      controller.emojiSelectedIndex.value = index;
                    },
                    onTap: () {
                      final _controller = controller.lastFocusedTextController;
                      final text = _controller.text;
                      final regExp = RegExp(r":[^: \n]+([ \n]|$)", multiLine: true);
                      final matches = regExp.allMatches(text);
                      if (matches.isNotEmpty && matches.any((m) => m.start < _controller.selection.start)) {
                        final match = matches.lastWhere((m) => m.start < _controller.selection.start);
                        final emojiChar = emoji.emoji;
                        _controller.text = "${text.substring(0, match.start)}$emojiChar ${text.substring(match.end)}";
                        _controller.selection =
                            TextSelection.fromPosition(TextPosition(offset: match.start + emojiChar.length + 1));
                      }
                      controller.emojiSelectedIndex.value = 0;
                      controller.emojiMatches.clear();
                      controller.lastFocusedNode.requestFocus();
                    },
                    child: ListTile(
                      mouseCursor: MouseCursor.defer,
                      dense: true,
                      selectedTileColor: context.theme.colorScheme.surfaceContainerHighest.oppositeLightenOrDarken(20),
                      selected: controller.emojiSelectedIndex.value == index,
                      title: Row(
                        children: <Widget>[
                          Text(
                            emoji.emoji,
                            style: context.textTheme.labelLarge!.apply(fontFamily: "Apple Color Emoji"),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ":${emoji.shortName}:",
                            style: context.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              itemCount: controller.emojiMatches.length,
            ),
          ),
        ),
      ),
    );
  }
}

/// Extracted mention suggestions to reduce parent rebuild scope
class _MentionSuggestions extends StatelessWidget {
  const _MentionSuggestions({
    required this.controller,
    required this.isIOS,
    required this.onSelect,
  });

  final ConversationViewController controller;
  final bool isIOS;
  final Function(int, bool) onSelect;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: min(controller.mentionMatches.length * 60, 180)),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Container(
          decoration: BoxDecoration(
            border: isIOS
                ? null
                : Border.fromBorderSide(
                    BorderSide(color: context.theme.colorScheme.surface, strokeAlign: BorderSide.strokeAlignOutside)),
            borderRadius: BorderRadius.circular(20),
            color: context.theme.colorScheme.surfaceContainerHighest,
          ),
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            radius: const Radius.circular(4),
            controller: controller.emojiScrollController,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 0),
              controller: controller.emojiScrollController,
              physics: ThemeSwitcher.getScrollPhysics(),
              shrinkWrap: true,
              findChildIndexCallback: (key) =>
                  findChildIndexByKey(controller.mentionMatches, key, (item) => item.address),
              itemBuilder: (BuildContext context, int index) {
                final mention = controller.mentionMatches[index];
                return Material(
                  key: ValueKey(mention.address),
                  color: Colors.transparent,
                  child: InkWell(
                    onTapDown: (details) {
                      controller.mentionSelectedIndex.value = index;
                    },
                    onTap: () {
                      onSelect(index, false);
                    },
                    onLongPress: () {
                      onSelect(index, true);
                    },
                    onSecondaryTapUp: (details) {
                      onSelect(index, true);
                    },
                    child: ListTile(
                      mouseCursor: MouseCursor.defer,
                      dense: true,
                      selectedTileColor: context.theme.colorScheme.surfaceContainerHighest.oppositeLightenOrDarken(20),
                      selected: controller.mentionSelectedIndex.value == index,
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ContactAvatarWidget(
                            handle: mention.handle,
                            size: 25,
                            fontSize: 15,
                            borderThickness: 0,
                            // A tap anywhere on the row picks the mention
                            editable: false,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            mention.displayName,
                            style: context.textTheme.labelLarge!,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!kIsWeb && mention.handle.contactsV2.isNotEmpty) const SizedBox(width: 8),
                          if (!kIsWeb && mention.handle.contactsV2.isNotEmpty)
                            Text(
                              mention.handle.formattedAddress ?? mention.address,
                              style: context.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              itemCount: controller.mentionMatches.length,
            ),
          ),
        ),
      ),
    );
  }
}
