import "dart:ffi";
import "dart:math";

import "package:bluebubbles/app/layouts/conversation_view/widgets/message/text/run_text_effects.dart";
import "package:bluebubbles/helpers/helpers.dart";
import "package:bluebubbles/database/models.dart";
import "package:bluebubbles/services/services.dart";
import 'package:bluebubbles/utils/emoji.dart';
import "package:bluebubbles/utils/emoticons.dart";
import "package:collection/collection.dart";
import "package:ffi/ffi.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:get/get.dart";
import 'package:languagetool_textfield/languagetool_textfield.dart';
import 'package:universal_io/io.dart';
import 'package:win32/win32.dart' show GetClipboardOwner, GetCurrentProcessId, GetWindowThreadProcessId;
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

  /// Leaves the name as plain text, keeping any formatting on it.
  void removeMention(Run mention) {
    final rest = Map<String, dynamic>.of(mention.attributes?.rawAttributes ?? const {})..remove(_mentionAttribute);
    runs = [
      for (final r in runs)
        if (r != mention) r else if (rest.isNotEmpty) Run(range: r.range, attributes: Attributes(rawAttributes: rest)),
    ];
    notifyListeners();
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
    var shifted = shiftRuns(text, newText, runs, anchor: start);
    // Formatting carried over the inserted text would overlap [run], and overlapping runs draw their text twice
    if (run != null) shifted = cutOut(shifted, run.range[0], run.range[0] + run.range[1]);
    runs = [...shifted, ?run]..sort((a, b) => a.range[0].compareTo(b.range[0]));
    // super's setter, so these runs aren't shifted a second time
    super.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
  }

  /// The text and formatting last copied from a composer or message. The system clipboard only holds plain text, so
  /// pasting that same text back puts these runs on it.
  static ({String text, List<Run> runs})? richClipboard;

  static const _mentionAttribute = '__kIMMentionConfirmedMention';
  static final _pastableAttributes = {...styleAttributes.values, effectAttribute, _mentionAttribute};

  /// Remembers [runs] (relative to [text]) for [richClipboard], keeping only what the composer can paste.
  static void rememberCopy(String text, List<Run> runs) {
    final kept = <Run>[];
    for (final run in runs) {
      final attrs = Map<String, dynamic>.of(run.attributes?.rawAttributes ?? const {})
        ..removeWhere((k, _) => !_pastableAttributes.contains(k));
      if (attrs.isNotEmpty) kept.add(Run(range: run.range, attributes: Attributes(rawAttributes: attrs)));
    }
    richClipboard = (text: text, runs: kept);
  }

  /// [rememberCopy] for the selection, before it's copied or cut.
  void rememberSelection() {
    final start = selection.start;
    final end = selection.end;
    if (start < 0 || start == end) return;
    rememberCopy(text.substring(start, end), copiedRuns(runs, start, end));
  }

  /// [runs] over [start, end), relative to [start]. A partly covered mention copies as plain text.
  @visibleForTesting
  static List<Run> copiedRuns(List<Run> runs, int start, int end) {
    final pieces = <Run>[];
    for (final (from, to, attrs) in segments(runs, start, end)) {
      if (attrs.isEmpty) continue;
      final mention = runs.firstWhereOrNull(
          (r) => r.attributes?.mention != null && r.range[0] <= from && to <= r.range[0] + r.range[1]);
      final whole = mention == null || (mention.range[0] >= start && mention.range[0] + mention.range[1] <= end);
      final kept = whole ? attrs : (Map<String, dynamic>.of(attrs)..remove(_mentionAttribute));
      if (kept.isEmpty) continue;
      pieces.add(Run(range: [from - start, to - from], attributes: Attributes(rawAttributes: kept)));
    }
    return pieces;
  }

  /// False where formatting isn't offered (a brand-new chat): every paste lands plain.
  bool allowFormatting = true;

  String? _pasting;
  List<Run> _pastingRuns = const [];
  bool _pastingPlain = false;

  /// Replaces the selection with pasted [pasted]: with its copied formatting when it came from [richClipboard], else
  /// with [htmlRuns] (the styles of the rich copy another app made, from htmlRuns()), else as plain text rather than
  /// picking up the formatting it lands next to. [plain] (Ctrl+Shift+V) always pastes plain text.
  void pasteText(String pasted, {List<Run> htmlRuns = const [], bool plain = false}) {
    final start = selection.start;
    if (start < 0) return;
    _pasting = pasted;
    _pastingRuns = htmlRuns;
    _pastingPlain = plain;
    value = TextEditingValue(
      text: text.replaceRange(start, selection.end, pasted),
      selection: TextSelection.collapsed(offset: start + pasted.length),
    );
    _pasting = null;
    _pastingRuns = const [];
    _pastingPlain = false;
  }

  /// [runs] of a [length]-long text with a paste's formatting on [start, start + pasted.length), replacing whatever
  /// the edit carried over: [richClipboard]'s runs when it holds [pasted] and was copied [fromHere], keeping only
  /// mentions of [addresses]; otherwise [otherRuns], styles another app copied, relative to [pasted].
  @visibleForTesting
  static List<Run> pastedRuns(
    List<Run> runs,
    int length,
    int start,
    String pasted,
    Set<String> addresses, {
    bool fromHere = true,
    List<Run> otherRuns = const [],
  }) {
    final end = start + pasted.length;
    for (final attribute in [...styleAttributes.values, effectAttribute]) {
      runs = restyle(runs, length, start, end, attribute, null);
    }
    final clip = richClipboard;
    if (!fromHere || clip == null || clip.text != pasted) {
      for (final run in otherRuns) {
        final from = start + run.range[0];
        for (final MapEntry(:key, :value) in run.attributes!.rawAttributes.entries) {
          if (styleAttributes.containsValue(key)) runs = restyle(runs, length, from, from + run.range[1], key, value);
        }
      }
      return runs;
    }
    for (final run in clip.runs) {
      final address = run.attributes!.mention;
      if (address != null && addresses.contains(address)) {
        runs = [
          ...runs,
          Run(range: [start + run.range[0], run.range[1]], attributes: Attributes(mention: address)),
        ]..sort((a, b) => a.range[0].compareTo(b.range[0]));
      }
    }
    for (final run in clip.runs) {
      final from = start + run.range[0];
      final to = from + run.range[1];
      for (final MapEntry(:key, :value) in run.attributes!.rawAttributes.entries) {
        if (key != _mentionAttribute) runs = restyle(runs, length, from, to, key, value);
      }
    }
    return runs;
  }

  /// Whether another app put what's on the clipboard there, so the same text copied elsewhere doesn't get our
  /// formatting. Only Windows says who copied last; elsewhere, and when it can't tell, the text alone decides.
  static bool _clipboardFromElsewhere() {
    if (!Platform.isWindows) return false;
    final owner = GetClipboardOwner().value;
    if (owner.address == 0) return false;
    return using((arena) {
      final pid = arena<Uint32>();
      GetWindowThreadProcessId(owner, pid);
      return pid.value != GetCurrentProcessId();
    });
  }

  @override
  set value(TextEditingValue newValue) {
    final pending = _pendingTyping;
    // A paste from anywhere (keyboard clipboard chip, context menu, Ctrl+V) that matches what was copied here
    final clipText = richClipboard?.text;
    final pasted = _pasting ??
        (clipText != null &&
                clipText.length > 1 &&
                selection.start >= 0 &&
                newValue.text == text.replaceRange(selection.start, selection.end, clipText)
            ? clipText
            : null);
    final pasteAt = selection.start;
    if (newValue.text == text) {
      if (!newValue.selection.isCollapsed || newValue.selection.baseOffset != _pendingAt) _pendingTyping = null;
      super.value = newValue;
      return;
    }
    _pendingTyping = null;
    final anchor = selection.start >= 0 && newValue.selection.start >= 0
        ? min(selection.start, newValue.selection.start)
        : null;
    final oldText = text;
    final newText = newValue.text;
    if (runs.isNotEmpty) runs = shiftRuns(oldText, newText, runs, anchor: anchor);
    final inserted = newText.length - oldText.length;
    if (pending != null &&
        inserted > 0 &&
        newText.startsWith(oldText.substring(0, _pendingAt)) &&
        newText.endsWith(oldText.substring(_pendingAt))) {
      for (final attribute in [...styleAttributes.values, effectAttribute]) {
        runs = restyle(runs, newText.length, _pendingAt, _pendingAt + inserted, attribute, pending[attribute]);
      }
    }
    if (pasted != null) {
      final addresses = mentionables.map((m) => m.address).toSet();
      runs = allowFormatting && !_pastingPlain
          ? pastedRuns(runs, newText.length, pasteAt, pasted, addresses,
              fromHere: !_clipboardFromElsewhere(), otherRuns: _pastingRuns)
          : pastedRuns(runs, newText.length, pasteAt, pasted, addresses, fromHere: false);
    }
    final before = newText;
    super.value = newValue;
    // Emoticon and shortcode replacement can rewrite the text on the way in.
    if (text != before) runs = shiftRuns(before, text, runs);
  }

  /// [runs] with [start, end) taken out of them, splitting any run that spans it.
  @visibleForTesting
  static List<Run> cutOut(List<Run> runs, int start, int end) {
    final out = <Run>[];
    for (final run in runs) {
      final from = run.range[0];
      final to = from + run.range[1];
      if (from < start) out.add(Run(range: [from, min(to, start) - from], attributes: run.attributes));
      if (to > end) out.add(Run(range: [max(from, end), to - max(from, end)], attributes: run.attributes));
    }
    return out;
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
      final typingAtEnd = end == prefix && oldEnd == prefix && run.attributes?.mention == null;
      if (end <= prefix && !typingAtEnd) {
        kept.add(run);
      } else if (typingAtEnd && run.attributes!.textEffect != null) {
        // Typing on from an effect carries its styles but not the effect itself
        kept.add(run);
        final rest = Map<String, dynamic>.of(run.attributes!.rawAttributes)..remove(effectAttribute);
        if (rest.isNotEmpty) kept.add(Run(range: [end, delta], attributes: Attributes(rawAttributes: rest)));
      } else if (typingAtEnd) {
        kept.add(Run(range: [start, run.range[1] + delta], attributes: run.attributes));
      } else if (start >= oldEnd) {
        kept.add(Run(range: [start + delta, run.range[1]], attributes: run.attributes));
      } else {
        // Editing inside a mention unmentions it; any formatting on it stays
        final attrs = Map<String, dynamic>.of(run.attributes?.rawAttributes ?? const {})
          ..remove('__kIMMentionConfirmedMention');
        // Text typed into it at the cursor splits it. A deletion, or a word replaced around the cursor (autocorrect,
        // which can look like an insertion in the middle), leaves it whole.
        final typedAtCursor = anchor == prefix && oldEnd == prefix && newEnd > prefix;
        if (attrs.containsKey(effectAttribute) && typedAtCursor) {
          // An effect only covers the text it was put on: the new text splits it and keeps just the styles
          final styles = Map<String, dynamic>.of(attrs)..remove(effectAttribute);
          final effect = Attributes(rawAttributes: attrs);
          if (start < prefix) kept.add(Run(range: [start, prefix - start], attributes: effect));
          if (styles.isNotEmpty && start < prefix && end > oldEnd) {
            kept.add(Run(range: [prefix, newEnd - prefix], attributes: Attributes(rawAttributes: styles)));
          }
          if (end > oldEnd) kept.add(Run(range: [newEnd, end + delta - newEnd], attributes: effect));
          continue;
        }
        final newStart = start < prefix ? start : newEnd;
        final newRunEnd = end > oldEnd ? end + delta : newEnd;
        if (attrs.isNotEmpty && newRunEnd > newStart) {
          kept.add(Run(range: [newStart, newRunEnd - newStart], attributes: Attributes(rawAttributes: attrs)));
        }
      }
    }
    return kept;
  }

  static const styleAttributes = {
    'bold': '__kIMTextBoldAttributeName',
    'italic': '__kIMTextItalicAttributeName',
    'underline': '__kIMTextUnderlineAttributeName',
    'strikethrough': '__kIMTextStrikethroughAttributeName',
  };

  static const effectAttribute = '__kIMTextEffectAttributeName';

  /// Adds the style [attribute] over the selection, or removes it when all of the selection already has it.
  void toggleStyle(String attribute) => _restyleSelection(attribute, 1, toggle: true);

  /// Puts text effect [id] on the selection, or clears its effect when null.
  void setEffect(int? id) {
    // An effect is only ever put on selected text
    if (!selection.isCollapsed) _restyleSelection(effectAttribute, id, toggle: false);
  }

  /// Formatting chosen for the next typed text at [_pendingAt] (with a collapsed cursor), overriding what it would
  /// otherwise pick up from the run it extends.
  Map<String, dynamic>? _pendingTyping;
  int _pendingAt = -1;

  /// The attributes the next typed text gets: a pending choice, else those of the run that typing extends.
  Map<String, dynamic> get typingAttributes {
    final caret = selection.baseOffset;
    if (!selection.isCollapsed || caret < 0) return const {};
    if (_pendingTyping != null && _pendingAt == caret) return _pendingTyping!;
    final attrs = runs
            .firstWhereOrNull(
                (r) => r.attributes?.mention == null && r.range[0] < caret && caret <= r.range[0] + r.range[1])
            ?.attributes
            ?.rawAttributes ??
        const <String, dynamic>{};
    // Typed text never takes an effect (see shiftRuns)
    return attrs.containsKey(effectAttribute) ? (Map.of(attrs)..remove(effectAttribute)) : attrs;
  }

  /// Whether typing would carry formatting or an effect forward from the cursor, or a choice for it is pending.
  bool get hasActiveFormatting =>
      (_pendingTyping != null && _pendingAt == selection.baseOffset) ||
      typingAttributes.keys.any((k) => k == effectAttribute || styleAttributes.containsValue(k));

  /// Whether all of the selection (or, with a collapsed cursor, the next typed text) has [attribute] set to [value].
  bool selectionHas(String attribute, Object value) {
    if (selection.isCollapsed) return typingAttributes[attribute] == value;
    final (start, end) = _selectionRange();
    return start < end && segments(runs, start, end).every((s) => s.$3[attribute] == value);
  }

  /// The effect on all of the selection (or the next typed text), or null when there is none or it's mixed.
  int? get selectionEffect {
    if (selection.isCollapsed) return typingAttributes[effectAttribute] as int?;
    final (start, end) = _selectionRange();
    if (start >= end) return null;
    final effects = segments(runs, start, end).map((s) => s.$3[effectAttribute]).toSet();
    return effects.length == 1 ? effects.single as int? : null;
  }

  /// The selection, widened to whole mentions: they are styled as a unit.
  (int, int) _selectionRange() {
    var start = selection.start;
    var end = selection.end;
    if (start < 0) return (0, 0);
    for (final mention in mentionRuns) {
      if (mention.range[0] < end && mention.range[0] + mention.range[1] > start) {
        start = min(start, mention.range[0]);
        end = max(end, mention.range[0] + mention.range[1]);
      }
    }
    return (start, end);
  }

  /// With [toggle], removes [attribute] instead when all of the selection already has [value].
  void _restyleSelection(String attribute, Object? value, {required bool toggle}) {
    if (selection.isCollapsed) {
      if (selection.baseOffset < 0) return;
      // Nothing to restyle yet: this sets what the next typed text gets
      final pending = Map<String, dynamic>.of(typingAttributes);
      value == null || (toggle && pending[attribute] == value) ? pending.remove(attribute) : pending[attribute] = value;
      _pendingTyping = pending;
      _pendingAt = selection.baseOffset;
      notifyListeners();
      return;
    }
    final (start, end) = _selectionRange();
    if (start >= end) return;
    runs = restyle(runs, text.length, start, end, attribute,
        value == null || (toggle && selectionHas(attribute, value)) ? null : value);
    notifyListeners();
  }

  /// [runs] with [attribute] set to [value] over [start, end) of a [length]-long text, or removed there when
  /// [value] is null. Adjacent runs that end up identical are merged; mentions never are.
  @visibleForTesting
  static List<Run> restyle(List<Run> runs, int length, int start, int end, String attribute, Object? value) {
    final out = <Run>[];
    for (final (from, to, attrs) in segments(runs, 0, length, [start, end])) {
      final changed = Map<String, dynamic>.of(attrs);
      if (from >= start && to <= end) value == null ? changed.remove(attribute) : changed[attribute] = value;
      if (changed.isEmpty) continue;
      final last = out.lastOrNull;
      if (last != null &&
          last.range[0] + last.range[1] == from &&
          changed['__kIMMentionConfirmedMention'] == null &&
          mapEquals(last.attributes!.rawAttributes, changed)) {
        out[out.length - 1] = Run(range: [last.range[0], to - last.range[0]], attributes: last.attributes);
      } else {
        out.add(Run(range: [from, to - from], attributes: Attributes(rawAttributes: changed)));
      }
    }
    return out;
  }

  /// [start, end) cut at every run edge and at [alsoCutAt], each piece with its covering run's attributes.
  static List<(int, int, Map<String, dynamic>)> segments(
    List<Run> runs,
    int start,
    int end, [
    Iterable<int> alsoCutAt = const [],
  ]) {
    final cuts = {start, end, ...alsoCutAt, for (final r in runs) ...[r.range[0], r.range[0] + r.range[1]]}
        .where((c) => c >= start && c <= end)
        .toList()
      ..sort();
    return [
      for (var i = 0; i + 1 < cuts.length; i++)
        (
          cuts[i],
          cuts[i + 1],
          runs
                  .firstWhereOrNull((r) => r.range[0] <= cuts[i] && cuts[i] < r.range[0] + r.range[1])
                  ?.attributes
                  ?.rawAttributes ??
              const <String, dynamic>{},
        ),
    ];
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
    final styled = runs.where((r) => r.range[0] + r.range[1] <= text.length).toList();
    if (styled.isEmpty) return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    final base = style ?? const TextStyle();
    final selStart = selection.isCollapsed ? -1 : selection.start;
    final selEnd = selection.isCollapsed ? -1 : selection.end;
    final children = <InlineSpan>[];
    var pos = 0;
    for (final run in styled) {
      final start = run.range[0];
      final end = start + run.range[1];
      final a = run.attributes!;
      if (start > pos) {
        children.add(
          buildMistakeTextSpans(context: context, chunk: text.substring(pos, start), offset: pos, style: style),
        );
      }
      final decorations = [
        if (a.isUnderlined) TextDecoration.underline,
        if (a.isStrikethrough) TextDecoration.lineThrough,
      ];
      final runStyle = base.copyWith(
        fontWeight: a.isBold || a.mention != null ? FontWeight.bold : null,
        fontStyle: a.isItalic ? FontStyle.italic : null,
        decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
        // TextEffectOverlay draws effect text animated on top of the field
        color: RunTextEffects.supports(a.textEffect)
            ? Colors.transparent
            : a.mention != null
                ? context.theme.colorScheme.primary
                : null,
      );
      // The selection highlight is solid primary too (main.dart), so selected mention text inverts to stay visible.
      // Effect text stays transparent: TextEffectOverlay draws it, inverted the same way.
      final selectedStyle = RunTextEffects.supports(a.textEffect)
          ? runStyle
          : runStyle.copyWith(color: context.theme.colorScheme.onPrimary);
      final cuts = a.mention == null
          ? [start, end]
          : ({start, selStart.clamp(start, end), selEnd.clamp(start, end), end}.toList()..sort());
      for (var i = 0; i + 1 < cuts.length; i++) {
        final selected = a.mention != null && cuts[i] >= selStart && cuts[i + 1] <= selEnd;
        children.add(TextSpan(
          children: buildAppleEmojiTextSpans(
            text: text.substring(cuts[i], cuts[i + 1]),
            style: selected ? selectedStyle : runStyle,
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
