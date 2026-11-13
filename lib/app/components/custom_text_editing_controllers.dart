import "dart:math";

import "package:bluebubbles/helpers/helpers.dart";
import "package:bluebubbles/database/models.dart";
import "package:bluebubbles/services/services.dart";
import 'package:bluebubbles/utils/emoji.dart';
import "package:bluebubbles/utils/emoticons.dart";
import "package:collection/collection.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:get/get.dart";
import 'package:languagetool_textfield/languagetool_textfield.dart';
import "package:languagetool_textfield/src/utils/closed_range.dart";
import "package:languagetool_textfield/src/utils/keep_latest_response_service.dart";

class Mentionable {
  Mentionable({required this.handle});

  final Handle handle;

  String get displayName {
    // For handles with a real contact, show first name only. For phone numbers
    // without a contact, show the full formatted address — splitting "+1 (555) 123-4567"
    // by space would yield just "+1" (the country code).
    if (!kIsWeb && handle.contactsV2.isNotEmpty) {
      return handle.displayName.split(" ").first;
    }
    return handle.displayName;
  }

  String get address => handle.address;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Mentionable && runtimeType == other.runtimeType && address == other.address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => displayName;
}

class SpellCheckTextEditingController extends TextEditingController {
  SpellCheckTextEditingController({super.text, this.focusNode}) {
    assert(focusNode != null || !(kIsDesktop || kIsWeb));
    _languageCheckService = DebounceLanguageCheckService(
        LanguageToolService(LanguageToolClient(language: SettingsSvc.settings.spellcheckLanguage.value)),
        const Duration(milliseconds: 1000));
    _processMistakes(text);
  }

  /// focusNode
  /// Required for spellcheck replacement to work
  FocusNode? focusNode;

  /// Language tool configs
  final HighlightStyle highlightStyle = const HighlightStyle();
  final _latestResponseService = KeepLatestResponseService();
  late final LanguageCheckService _languageCheckService;

  /// List which contains Mistake objects spans are built from
  List<Mistake> _mistakes = [];
  int _selectedMistakeIndex = -1;

  Mistake? get selectedMistake => _selectedMistakeIndex == -1 ? null : _mistakes.elementAtOrNull(_selectedMistakeIndex);

  Object? _fetchError;

  /// An error that may have occurred during the API fetch.
  Object? get fetchError => _fetchError;

  /// Mistake tooltip
  OverlayEntry? _mistakeTooltip;

  @override
  set value(TextEditingValue newValue) {
    String origText = newValue.text;
    int origOffset = newValue.selection.start;
    String newText = newValue.text;
    int newOffset = newValue.selection.start;

    // OPTIMIZATION: Skip processing if only selection changed (cursor moved, no text change)
    if (origText == text && origOffset != selection.start) {
      // Only selection changed, skip all text processing
      if (kIsDesktop || kIsWeb) {
        _handleSelectionChange(newValue.selection);
        // Only remove tooltip when selection changes
        _mistakeTooltip?.remove();
        _mistakeTooltip = null;
      }
      super.value = newValue;
      return;
    }

    if (SettingsSvc.settings.replaceEmoticonsWithEmoji.value) {
      List<(int, int)> offsetsAndDifferences;
      (newText, offsetsAndDifferences) = replaceEmoticons(newText);

      if (offsetsAndDifferences.isNotEmpty) {
        // Add all differences before the cursor and subtract from offset
        for (final (_offset, difference) in offsetsAndDifferences) {
          if (_offset < newOffset) {
            newOffset -= difference;
          }
        }
      }
    }

    final regExp = RegExp(r"(?<=^|[^a-zA-Z\d]):[^: \n]{2,}:", multiLine: true);
    final match = regExp.allMatches(newText).lastWhereOrNull((m) => m.start < newOffset);
    if (match != null) {
      // Full emoji text (do not search for partial matches)
      String emojiName = newText.substring(match.start + 1, match.end - 1).toLowerCase();
      if (shortNameToEmoji.keys.contains(emojiName) || shortNameToSkinToneEmoji.keys.contains(emojiName)) {
        // We can replace the :emoji: with the actual emoji here
        final emoji = shortNameToEmoji[emojiName] ?? shortNameToSkinToneEmoji[emojiName]!;
        newText = newText.substring(0, match.start) + emoji.emoji + newText.substring(match.end);
        newOffset = match.start + emoji.emoji.length;
      }
    }

    if (newText != origText || newOffset != origOffset) {
      newValue = newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    }

    if (kIsDesktop || kIsWeb) {
      // Only process text change if text actually changed
      if (newValue.text != text) {
        _handleTextChange(newValue.text);
      }
    }

    super.value = newValue;
  }

  @override
  set selection(TextSelection newSelection) {
    if (kIsDesktop || kIsWeb) {
      _handleSelectionChange(newSelection);
    }
    super.selection = newSelection;
  }

  @override
  void dispose() {
    _languageCheckService.dispose();
    _mistakeTooltip?.remove();
    _mistakeTooltip = null;
    super.dispose();
  }

  /// Replaces mistake with given replacement
  void replaceMistake(Mistake mistake, String replacement) {
    final mistakes = List<Mistake>.from(_mistakes);
    mistakes.remove(mistake);
    _mistakes = mistakes;
    text = text.replaceRange(mistake.offset, mistake.endOffset, replacement);
    Future.microtask.call(() {
      final newOffset = mistake.offset + replacement.length;
      selection = TextSelection.fromPosition(TextPosition(offset: newOffset));
      focusNode?.requestFocus();
    });
  }

  /// Clear mistakes list when text mas modified and get a new list of mistakes
  /// via API
  Future<void> _handleTextChange(String newText) async {
    ///set value triggers each time, even when cursor changes its location
    ///so this check avoid cleaning Mistake list when text wasn't really changed
    if (newText == text) return;

    await _processMistakes(newText);
  }

  Future<void> _handleSelectionChange(TextSelection newSelection) async {
    if (newSelection.baseOffset == newSelection.extentOffset) {
      _selectedMistakeIndex = -1;
      return;
    }
    final mistakeIndex = _mistakes
        .indexWhere((e) => (e.offset == newSelection.baseOffset) && (e.endOffset == newSelection.extentOffset));
    if (mistakeIndex != -1) {
      _selectedMistakeIndex = mistakeIndex;
    } else {
      _selectedMistakeIndex = -1;
    }
  }

  Future<void> _processMistakes(String newText) async {
    if (!SettingsSvc.settings.spellcheck.value || newText.isEmpty) {
      _mistakes.clear();
      _mistakeTooltip?.remove();
      _mistakeTooltip = null;
      notifyListeners();
      return;
    }
    final filteredMistakes = _filterMistakesOnChanged(newText);
    _mistakes = filteredMistakes.toList();

    final mistakesWrapper = await _latestResponseService.processLatestOperation(
      () => _languageCheckService.findMistakes(newText),
    );
    if (mistakesWrapper == null || !mistakesWrapper.hasResult) return;

    final mistakes = mistakesWrapper.result();
    _fetchError = mistakesWrapper.error;

    _mistakes = List.from(mistakes);
    notifyListeners();
  }

  /// Filters the list of mistakes based on the changes
  /// in the text when it is changed.
  Iterable<Mistake> _filterMistakesOnChanged(String newText) sync* {
    final isSelectionRangeEmpty = selection.end == selection.start;
    final lengthDiscrepancy = newText.length - text.length;

    for (final mistake in _mistakes) {
      Mistake? newMistake;

      newMistake = isSelectionRangeEmpty
          ? _adjustMistakeOffsetWithCaretCursor(
              mistake: mistake,
              lengthDiscrepancy: lengthDiscrepancy,
            )
          : _adjustMistakeOffsetWithSelectionRange(
              mistake: mistake,
              lengthDiscrepancy: lengthDiscrepancy,
            );

      if (newMistake != null) yield newMistake;
    }
  }

  /// Adjusts the mistake offset when the selection is a caret cursor.
  Mistake? _adjustMistakeOffsetWithCaretCursor({
    required Mistake mistake,
    required int lengthDiscrepancy,
  }) {
    final mistakeRange = ClosedRange(mistake.offset, mistake.endOffset);
    final caretLocation = selection.base.offset;

    // Don't highlight mistakes on changed text
    // until we get an update from the API.
    final isCaretOnMistake = mistakeRange.contains(caretLocation);
    if (isCaretOnMistake) return null;

    final shouldAdjustOffset = mistakeRange.isBeforeOrAt(caretLocation);
    if (!shouldAdjustOffset) return mistake;

    final newOffset = mistake.offset + lengthDiscrepancy;

    return mistake.copyWith(offset: newOffset);
  }

  /// Adjusts the mistake offset when the selection is a range.
  Mistake? _adjustMistakeOffsetWithSelectionRange({
    required Mistake mistake,
    required int lengthDiscrepancy,
  }) {
    final selectionRange = ClosedRange(selection.start, selection.end);
    final mistakeRange = ClosedRange(mistake.offset, mistake.endOffset);

    final hasSelectedTextChanged = selectionRange.overlapsWith(mistakeRange);
    if (hasSelectedTextChanged) return null;

    final shouldAdjustOffset = selectionRange.isAfterOrAt(mistake.offset);
    if (!shouldAdjustOffset) return mistake;

    final newOffset = mistake.offset + lengthDiscrepancy;

    return mistake.copyWith(offset: newOffset);
  }

  OverlayEntry _createTooltip(BuildContext context, Offset offset, Mistake mistake, String mistakeText) {
    final Color color = highlightStyle.colors.colorOf(mistake.type);
    Iterable<String> replacements = mistake.replacements.take(15);
    return OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx - 100,
        width: 200,
        bottom: (context.height - offset.dy) ~/ 60 * 60 + 60,
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: context.theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.all(8.0),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mistake.type.value.capitalizeFirst!,
                      style: context.textTheme.titleSmall!.copyWith(color: color)),
                  Text(
                    "\"$mistakeText\"",
                    style: context.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 8.0),
                  replacements.isEmpty
                      ? Text(
                          "No Replacements",
                          style: context.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.outline),
                        )
                      : Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4.0,
                          runSpacing: 4.0,
                          children: List.generate(replacements.length, (index) {
                            final replacement = mistake.replacements[index];
                            return InkWell(
                              borderRadius: BorderRadius.circular(8.0),
                              hoverColor: color.withValues(alpha: 0.2),
                              onTapDown: (_) {
                                replaceMistake(mistake, replacement);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4.0),
                                decoration: BoxDecoration(
                                  border: Border.all(color: context.theme.colorScheme.outline),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Text(replacement, style: context.textTheme.bodySmall),
                                ),
                              ),
                            );
                          }),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a TextSpan with mistakes highlighted
  /// [chunk] - the text chunk to build TextSpan for
  /// [offset] - the offset of the chunk in the whole text
  /// [endOffset] - the end offset of the chunk in the whole text
  /// [style] - the style to apply to the text
  TextSpan buildMistakeTextSpans({
    required BuildContext context,
    required String chunk,
    required int offset,
    TextStyle? style,
  }) {
    // Only spellcheck on desktop/web
    if (kIsDesktop || kIsWeb) {
      // Check if there are mistakes in this chunk
      int endOffset = offset + chunk.length;
      final mistakes = _mistakes.where((e) => e.offset >= offset && e.endOffset <= endOffset).toList();
      List<InlineSpan> spans = [];
      if (mistakes.isNotEmpty) {
        // Split text into mistakes and nonmistakes
        for (int i = 0; i < mistakes.length; i++) {
          final mistake = mistakes[i];
          final mistakeStart = mistake.offset - offset;
          final mistakeEnd = mistake.endOffset - offset;
          final mistakeText = chunk.substring(mistakeStart, mistakeEnd);
          final mistakeStyle = (style ?? const TextStyle()).copyWith(
            backgroundColor:
                highlightStyle.colors.colorOf(mistake.type).withValues(alpha: highlightStyle.backgroundOpacity),
            decoration: highlightStyle.decoration,
            decorationColor: highlightStyle.colors.colorOf(mistake.type),
            decorationThickness: highlightStyle.mistakeLineThickness,
          );

          final prevMistakeEnd = i == 0 ? 0 : mistakes[i - 1].endOffset - offset;
          final leadingNonMistakeText = chunk.substring(prevMistakeEnd, mistakeStart);
          if (leadingNonMistakeText.isNotEmpty) {
            spans.addAll(buildAppleEmojiTextSpans(text: leadingNonMistakeText, style: style));
          }

          spans.add(
            TextSpan(
              text: mistakeText,
              style: mistakeStyle,
              onEnter: (event) {
                if (_mistakeTooltip != null) {
                  _mistakeTooltip!.remove();
                }
                _mistakeTooltip = _createTooltip(
                    context,
                    Offset(event.position.dx - NavigationSvc.widthChatListLeft(context), event.position.dy),
                    mistake,
                    mistakeText);
                Overlay.of(context).insert(_mistakeTooltip!);
              },
            ),
          );

          if (i == mistakes.length - 1) {
            final nextMistakeStart = i == mistakes.length - 1 ? chunk.length : mistakes[i + 1].offset - offset;
            final trailingNonMistakeText = chunk.substring(mistakeEnd, nextMistakeStart);
            if (trailingNonMistakeText.isNotEmpty) {
              spans.addAll(buildAppleEmojiTextSpans(text: trailingNonMistakeText, style: style));
            }
          }
        }
        return TextSpan(children: spans);
      }
    }

    return TextSpan(children: buildAppleEmojiTextSpans(text: chunk, style: style));
  }

  List<InlineSpan> buildAppleEmojiTextSpans({required String text, required TextStyle? style}) {
    // OPTIMIZATION: Early exit if font doesn't exist to avoid regex processing
    if (!FilesystemSvc.fontExistsOnDisk.value) return [TextSpan(text: text, style: style)];

    // OPTIMIZATION: Cache regex matches to avoid recomputation on every render
    final emojiMatches = emojiRegex.allMatches(text);
    if (emojiMatches.isEmpty) return [TextSpan(text: text, style: style)];

    List<InlineSpan> spans = [];
    int lastIndex = 0;
    for (final match in emojiMatches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start), style: style));
      }
      spans.add(
        TextSpan(
            text: match.group(0),
            style:
                style?.copyWith(fontFamily: "Apple Color Emoji") ?? const TextStyle(fontFamily: "Apple Color Emoji")),
      );
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: style));
    }

    return spans;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return buildMistakeTextSpans(context: context, chunk: text, offset: 0, style: style);
  }
}

class MentionTextEditingController extends SpellCheckTextEditingController {
  MentionTextEditingController({super.text, super.focusNode, this.mentionables = const <Mentionable>[]});

  List<Mentionable> mentionables;

  /// Attributed runs over [text] in UTF-16 offsets, sorted and non-overlapping.
  List<Run> runs = [];

  Iterable<Run> get mentionRuns => runs.where((r) => r.attributes?.mention != null);

  Mentionable? mentionableFor(Run run) => mentionables.firstWhereOrNull((m) => m.address == run.attributes?.mention);

  void setTextAndRuns(String newText, List<Run> newRuns) {
    runs = newRuns.where((r) => r.range[0] >= 0 && r.range[0] + r.range[1] <= newText.length).toList()
      ..sort((a, b) => a.range[0].compareTo(b.range[0]));
    super.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  void copyFrom(MentionTextEditingController other) => setTextAndRuns(other.text, other.runs);

  /// Replaces the "@query" or partly typed name at the cursor. False when there's nothing there.
  bool addMention(Mentionable mentionable, {String? name}) {
    final cursor = selection.baseOffset;
    if (cursor < 0) return false;
    final start = RegExp(r"@?[^\s@]*$").firstMatch(text.substring(0, cursor))!.start;
    if (start == cursor) return false;
    final end = cursor + RegExp(r"^[^\s@]*").firstMatch(text.substring(cursor))!.end;
    final display = name ?? mentionable.displayName;
    final addSpace = !text.substring(end).startsWith(" ");
    _replace(start, end, display + (addSpace ? " " : ""),
        run: Run(range: [start, display.length], attributes: Attributes(mention: mentionable.address)));
    return true;
  }

  void removeMention(Run mention) {
    final start = mention.range[0];
    final end = start + mention.range[1];
    runs = runs.where((r) => r != mention).toList();
    _replace(start, end, "@${text.substring(start, end)}");
    // Past the following space, or the cursor sits on an "@name" and reopens the mention picker
    final cursor = selection.baseOffset;
    if (text.startsWith(" ", cursor)) selection = TextSelection.collapsed(offset: cursor + 1);
  }

  void renameMention(Run mention, String name) {
    final start = mention.range[0];
    runs = runs.where((r) => r != mention).toList();
    _replace(
      start,
      start + mention.range[1],
      name,
      run: Run(range: [start, name.length], attributes: mention.attributes),
    );
  }

  void _replace(int start, int end, String insert, {Run? run}) {
    final newText = text.replaceRange(start, end, insert);
    runs = [...shiftRuns(text, newText, runs, anchor: start), ?run]..sort((a, b) => a.range[0].compareTo(b.range[0]));
    // super's setter, so these runs aren't shifted a second time
    super.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    if (runs.isEmpty || newValue.text == text) {
      super.value = newValue;
      return;
    }
    final anchor = selection.start >= 0 && newValue.selection.start >= 0
        ? min(selection.start, newValue.selection.start)
        : null;
    runs = shiftRuns(text, newValue.text, runs, anchor: anchor);
    final before = newValue.text;
    super.value = newValue;
    // Emoticon and shortcode replacement can rewrite the text on the way in.
    if (text != before) runs = shiftRuns(before, text, runs);
  }

  /// [anchor] caps where the edit can start (the cursor): typing "S" before "Sam" otherwise reads as an edit
  /// inside the mention.
  @visibleForTesting
  static List<Run> shiftRuns(String oldText, String newText, List<Run> runs, {int? anchor}) {
    if (oldText == newText) return runs;
    final maxCommon = min(oldText.length, newText.length);
    final maxPrefix = min(maxCommon, anchor ?? maxCommon);
    var prefix = 0;
    while (prefix < maxPrefix && oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < maxCommon - prefix &&
        oldText.codeUnitAt(oldText.length - 1 - suffix) == newText.codeUnitAt(newText.length - 1 - suffix)) {
      suffix++;
    }
    final oldEnd = oldText.length - suffix;
    final newEnd = newText.length - suffix;
    final delta = newText.length - oldText.length;
    final kept = <Run>[];
    for (final run in runs) {
      final start = run.range[0];
      final end = start + run.range[1];
      if (end <= prefix) {
        kept.add(run);
      } else if (start >= oldEnd) {
        kept.add(Run(range: [start + delta, run.range[1]], attributes: run.attributes));
      } else if (run.attributes?.mention == null) {
        final newStart = start < prefix ? start : newEnd;
        final newRunEnd = end > oldEnd ? end + delta : newEnd;
        if (newRunEnd > newStart) kept.add(Run(range: [newStart, newRunEnd - newStart], attributes: run.attributes));
      }
    }
    return kept;
  }

  /// Converts a draft saved in the old format, where a mention was `U+FFFC index U+FFFC` into [mentionables].
  static (String, List<Run>) parseLegacyDraft(String draft, List<Mentionable> mentionables) {
    final runs = <Run>[];
    final out = StringBuffer();
    var last = 0;
    for (final match in RegExp('￼(\\d+)￼').allMatches(draft)) {
      out.write(draft.substring(last, match.start));
      final mention = mentionables.elementAtOrNull(int.parse(match.group(1)!));
      if (mention != null) {
        runs.add(
          Run(
            range: [out.length, mention.displayName.length],
            attributes: Attributes(mention: mention.address),
          ),
        );
        out.write(mention.displayName);
      }
      last = match.end;
    }
    out.write(draft.substring(last));
    return (out.toString(), runs);
  }

  /// Sendable attributed-body runs: the whole string covered, all in message part 0.
  static List<Run> attributedRuns(String text, List<Run> runs) {
    if (runs.isEmpty) return const [];
    final out = <Run>[];
    var pos = 0;
    for (final run in runs) {
      if (run.range[0] > pos) out.add(Run(range: [pos, run.range[0] - pos], attributes: Attributes(messagePart: 0)));
      out.add(
        Run(
          range: run.range,
          attributes: Attributes(rawAttributes: run.attributes!.rawAttributes, messagePart: 0),
        ),
      );
      pos = run.range[0] + run.range[1];
    }
    if (pos < text.length) out.add(Run(range: [pos, text.length - pos], attributes: Attributes(messagePart: 0)));
    return out;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final mentions = mentionRuns.where((r) => r.range[0] + r.range[1] <= text.length).toList();
    if (mentions.isEmpty) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    final bold = (style ?? const TextStyle()).copyWith(fontWeight: FontWeight.bold);
    final mentionStyle = bold.copyWith(color: context.theme.colorScheme.primary);
    // The selection highlight is solid primary too (main.dart), so selected mention text inverts to stay visible
    final selectedStyle = bold.copyWith(color: context.theme.colorScheme.onPrimary);
    final selStart = selection.isCollapsed ? -1 : selection.start;
    final selEnd = selection.isCollapsed ? -1 : selection.end;
    final children = <InlineSpan>[];
    var pos = 0;
    for (final mention in mentions) {
      final start = mention.range[0];
      final end = start + mention.range[1];
      if (start > pos) {
        children.add(
          buildMistakeTextSpans(context: context, chunk: text.substring(pos, start), offset: pos, style: style),
        );
      }
      final cuts = {start, selStart.clamp(start, end), selEnd.clamp(start, end), end}.toList()..sort();
      for (var i = 0; i + 1 < cuts.length; i++) {
        final selected = cuts[i] >= selStart && cuts[i + 1] <= selEnd;
        children.add(TextSpan(
          children: buildAppleEmojiTextSpans(
            text: text.substring(cuts[i], cuts[i + 1]),
            style: selected ? selectedStyle : mentionStyle,
          ),
        ));
      }
      pos = end;
    }
    if (pos < text.length) {
      children.add(buildMistakeTextSpans(context: context, chunk: text.substring(pos), offset: pos, style: style));
    }
    return TextSpan(style: style, children: children);
  }
}
