import 'dart:math';

import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/dialogs/custom_mention_dialog.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/picked_attachment.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
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
  OptimizedState createState() => _PickedAttachmentsHolderState();
}

class _PickedAttachmentsHolderState extends OptimizedState<PickedAttachmentsHolder> {
  
  List<PlatformFile> get pickedAttachments => widget.controller != null
      ? widget.controller!.pickedAttachments : widget.initialAttachments;

  void selectMention(int index, bool custom) async {
    if (widget.textController is! MentionTextEditingController) return;
    final mention = widget.controller!.mentionMatches[index];
    if (custom) {
      final changed = await showCustomMentionDialog(context, mention);
      if (isNullOrEmpty(changed)) return;
      mention.customDisplayName = changed!;
    }
    final _controller = widget.textController as MentionTextEditingController;
    widget.controller!.mentionSelectedIndex.value = 0;
    final text = _controller.text;
    final regExp = RegExp(r"@(?:[^@ \n]+|$)(?=[ \n]|$)", multiLine: true);
    final matches = regExp.allMatches(text);
    if (matches.isNotEmpty && matches.any((m) => m.start < _controller.selection.start)) {
      final match = matches.lastWhere((m) => m.start < _controller.selection.start);
      _controller.addMention(text.substring(match.start, match.end), mention);
    }
    widget.controller!.mentionMatches.clear();
    widget.controller!.focusNode.requestFocus();
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Obx(() {
          if (pickedAttachments.isNotEmpty) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: iOS ? 150 : 100,
                minHeight: iOS ? 150 : 100,
              ),
              child: Padding(
                padding: iOS ? EdgeInsets.zero : const EdgeInsets.only(left: 7.5, right: 7.5),
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
                                pickedAttachments.removeWhere((e) => e.path == file.path);
                                setState(() {});
                              }
                            },
                          );
                        },
                        childCount: pickedAttachments.length,
                      ),
                    )
                  ],
                ),
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        }),
        if (widget.controller != null)
          Obx(() {
            if (widget.controller!.emojiMatches.isNotEmpty) {
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: min(widget.controller!.emojiMatches.length * 60, 180)),
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: iOS ? null : Border.fromBorderSide(
                        BorderSide(color: context.theme.colorScheme.background, strokeAlign: BorderSide.strokeAlignOutside)
                      ),
                      borderRadius: BorderRadius.circular(20),
                      color: context.theme.colorScheme.properSurface,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Scrollbar(
                      radius: const Radius.circular(4),
                      controller: widget.controller!.emojiScrollController,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        controller: widget.controller!.emojiScrollController,
                        physics: ThemeSwitcher.getScrollPhysics(),
                        shrinkWrap: true,
                        findChildIndexCallback: (key) => findChildIndexByKey(widget.controller!.emojiMatches, key, (item) => item.shortName),
                        itemBuilder: (BuildContext context, int index) => Material(
                          key: ValueKey(widget.controller!.emojiMatches[index].shortName),
                          color: Colors.transparent,
                          child: InkWell(
                            onTapDown: (details) {
                              widget.controller!.emojiSelectedIndex.value = index;
                            },
                            onTap: () {
                              final _controller = widget.controller!.lastFocusedTextController;
                              final text = _controller.text;
                              final regExp = RegExp(r":[^: \n]+([ \n]|$)", multiLine: true);
                              final matches = regExp.allMatches(text);
                              if (matches.isNotEmpty && matches.any((m) => m.start < _controller.selection.start)) {
                                final match = matches.lastWhere((m) => m.start < _controller.selection.start);
                                final char = widget.controller!.emojiMatches[index].char;
                                _controller.text = "${text.substring(0, match.start)}$char ${text.substring(match.end)}";
                                _controller.selection = TextSelection.fromPosition(TextPosition(offset: match.start + char.length + 1));
                              }
                              widget.controller!.emojiSelectedIndex.value = 0;
                              widget.controller!.emojiMatches.clear();
                              widget.controller!.lastFocusedNode.requestFocus();
                            },
                            child: Obx(() => ListTile(
                                mouseCursor: MouseCursor.defer,
                                dense: true,
                                selectedTileColor: context.theme.colorScheme.properSurface.oppositeLightenOrDarken(20),
                                selected: widget.controller!.emojiSelectedIndex.value == index,
                                title: Row(
                                  children: <Widget>[
                                    Text(
                                      widget.controller!.emojiMatches[index].char,
                                      style:
                                      context.textTheme.labelLarge!.apply(fontFamily: "Apple Color Emoji"),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ":${widget.controller!.emojiMatches[index].shortName}:",
                                      style: context.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                )),
                            ),
                          ),
                        ),
                        itemCount: widget.controller!.emojiMatches.length,
                      ),
                    ),
                  ),
                ),
              );
            } else if (widget.controller!.mentionMatches.isNotEmpty) {
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: min(widget.controller!.mentionMatches.length * 60, 180)),
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: iOS ? null : Border.fromBorderSide(
                          BorderSide(color: context.theme.colorScheme.background, strokeAlign: BorderSide.strokeAlignOutside)
                      ),
                      borderRadius: BorderRadius.circular(20),
                      color: context.theme.colorScheme.properSurface,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Scrollbar(
                      radius: const Radius.circular(4),
                      controller: widget.controller!.emojiScrollController,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 0),
                        controller: widget.controller!.emojiScrollController,
                        physics: ThemeSwitcher.getScrollPhysics(),
                        shrinkWrap: true,
                        findChildIndexCallback: (key) => findChildIndexByKey(widget.controller!.mentionMatches, key, (item) => item.address),
                        itemBuilder: (BuildContext context, int index) => Material(
                          key: ValueKey(widget.controller!.mentionMatches[index].address),
                          color: Colors.transparent,
                          child: InkWell(
                            onTapDown: (details) {
                              widget.controller!.mentionSelectedIndex.value = index;
                            },
                            onTap: () {
                              selectMention(index, false);
                            },
                            onLongPress: () {
                              selectMention(index, true);
                            },
                            onSecondaryTapUp: (details) {
                              selectMention(index, true);
                            },
                            child: Obx(() => ListTile(
                                mouseCursor: MouseCursor.defer,
                                dense: true,
                                selectedTileColor: context.theme.colorScheme.properSurface.oppositeLightenOrDarken(20),
                                selected: widget.controller!.mentionSelectedIndex.value == index,
                                title: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    ContactAvatarWidget(
                                      handle: widget.controller!.mentionMatches[index].handle,
                                      size: 25,
                                      fontSize: 15,
                                      borderThickness: 0,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      widget.controller!.mentionMatches[index].displayName,
                                      style:
                                      context.textTheme.labelLarge!,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (widget.controller!.mentionMatches[index].displayName != widget.controller!.mentionMatches[index].address)
                                      const SizedBox(width: 8),
                                    if (widget.controller!.mentionMatches[index].displayName != widget.controller!.mentionMatches[index].address)
                                      Text(
                                        widget.controller!.mentionMatches[index].address,
                                        style: context.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                )),
                            ),
                          ),
                        ),
                        itemCount: widget.controller!.mentionMatches.length,
                      ),
                    ),
                  ),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          }),
      ],
    );
  }
}
