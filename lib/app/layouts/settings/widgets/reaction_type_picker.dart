import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/widgets/emoji_tapback_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/ui/reaction_helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

/// Reusable widget for selecting a reaction type
/// Used in Private API settings and Notification settings
class ReactionTypePicker extends StatefulWidget {
  final String title;

  /// One of [reactions], or an emoji when [allowEmoji] picked one
  final String currentValue;
  final List<String> reactions;
  final Function(String?) onChanged;
  final Color secondaryColor;
  final bool useModernMenu;

  /// Offer an option that picks an emoji, which [onChanged] reports as the emoji itself
  final bool allowEmoji;

  const ReactionTypePicker({
    super.key,
    required this.title,
    required this.currentValue,
    required this.reactions,
    required this.onChanged,
    required this.secondaryColor,
    this.useModernMenu = false,
    this.allowEmoji = false,
  });

  @override
  State<ReactionTypePicker> createState() => _ReactionTypePickerState();
}

class _ReactionTypePickerState extends State<ReactionTypePicker> {
  static const String _emojiOption = ReactionTypes.EMOJI;

  late String selectedValue;

  bool get _isEmoji => !widget.reactions.contains(selectedValue);

  @override
  void initState() {
    super.initState();
    selectedValue = widget.currentValue;
  }

  @override
  void didUpdateWidget(ReactionTypePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentValue != oldWidget.currentValue) {
      selectedValue = widget.currentValue;
    }
  }

  Future<void> _select(String? val) async {
    if (val == _emojiOption) {
      val = (await showEmojiTapbackPicker(context) as EmojiTapbackPick?)?.emoji;
      if (val == null || !mounted) return;
    }
    setState(() => selectedValue = val!);
    widget.onChanged(val);
  }

  @override
  Widget build(BuildContext context) {
    // A saved emoji keeps its option even when the server can no longer send one, so the selection still shows
    final options = [...widget.reactions, if (widget.allowEmoji || _isEmoji) _emojiOption];
    // All drawn as received tapbacks, so selecting one doesn't move or recolor it; the highlight shows the selection.
    // The received color comes from the saved theme, as a chat reads it: the app's theme doesn't carry it.
    final saved =
        ThemeStruct.resolveByName(null, ThemeSvc.inDarkMode(context) ? Brightness.dark : Brightness.light).data;
    final chatTheme = Theme.of(context).copyWith(extensions: saved.extensions.values);
    // On the selected emoji, so it can be changed: picking the selected option again doesn't reach onChanged everywhere
    final editPencil = GestureDetector(
      onTap: () => _select(_emojiOption),
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(Icons.edit_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
      ),
    );
    final customWidgets = options.map((reaction) {
      final emoji = reaction == _emojiOption;
      Widget widget = emoji && !_isEmoji
          ? const Icon(Icons.add_reaction_outlined)
          : Theme(
              data: chatTheme,
              child: ReactionWidget(
                // Received tapbacks point left; the static render's default has it reversed
                tailDirection: ReactionTailDirection.left,
                reaction: Message(
                  guid: "",
                  associatedMessageType: reaction,
                  associatedMessageEmoji: emoji ? selectedValue : null,
                  isFromMe: false,
                ),
              ),
            );
      if (emoji && _isEmoji) {
        widget = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _select(_emojiOption),
          child: Row(mainAxisSize: MainAxisSize.min, children: [widget, editPencil]),
        );
      }
      return Padding(
        key: ValueKey(reaction),
        padding: const EdgeInsets.symmetric(vertical: 7.5),
        child: widget,
      );
    }).toList();

    return SettingsOptions<String>(
      title: widget.title,
      options: options,
      cupertinoCustomWidgets: customWidgets,
      materialCustomWidgets: (option) => option == _emojiOption && _isEmoji
          ? Row(mainAxisSize: MainAxisSize.min, children: [Text(selectedValue), editPencil])
          : null,
      initial: _isEmoji ? _emojiOption : selectedValue,
      textProcessing: (val) => val != _emojiOption ? val : (_isEmoji ? selectedValue : "Emoji"),
      onChanged: _select,
      secondaryColor: widget.secondaryColor,
      useModernMenu: widget.useModernMenu,
    );
  }
}
