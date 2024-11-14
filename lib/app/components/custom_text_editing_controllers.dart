import "dart:math";

import "package:bluebubbles/helpers/helpers.dart";
import "package:bluebubbles/database/models.dart";
import "package:bluebubbles/services/services.dart";
import 'package:bluebubbles/utils/emoji.dart';
import "package:bluebubbles/utils/emoticons.dart";
import "package:collection/collection.dart";
import "package:emojis/emoji.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:get/get.dart";
import "package:languagetool_textfield/src/core/enums/mistake_type.dart";
import 'package:languagetool_textfield/languagetool_textfield.dart';
import "package:languagetool_textfield/src/utils/closed_range.dart";
import "package:languagetool_textfield/src/utils/keep_latest_response_service.dart";

class Mentionable {
  Mentionable({required this.handle});

  final Handle handle;
  String? customDisplayName;

  String get displayName => customDisplayName ?? handle.displayName.split(" ").first;

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
    _languageCheckService =
        DebounceLangToolService(LangToolService(LanguageToolClient(language: ss.settings.spellcheckLanguage.value)),
            const Duration(milliseconds: 500));
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

    if (ss.settings.replaceEmoticonsWithEmoji.value) {
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
    final matches = regExp.allMatches(newText);
    if (matches.isNotEmpty) {
      RegExpMatch match = matches.lastWhere((m) => m.start < newOffset);
      // Full emoji text (do not search for partial matches)
      String emojiName = newText.substring(match.start + 1, match.end - 1).toLowerCase();
      if (emojiNames.keys.contains(emojiName)) {
        // We can replace the :emoji: with the actual emoji here
        final emoji = Emoji.byShortName(emojiName)!;
        newText = newText.substring(0, match.start) + emoji.char + newText.substring(match.end);
        newOffset = match.start + emoji.char.length;
      }
    }

    if (newText != origText || newOffset != origOffset) {
      newValue = newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    }

    if (kIsDesktop || kIsWeb) {
      _handleTextChange(newValue.text);
      _mistakeTooltip?.remove();
      _mistakeTooltip = null;
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
    if (!ss.settings.spellcheck.value || newText.isEmpty) {
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

  /// Returns color for mistake TextSpan style
  Color _getMistakeColor(MistakeType type) {
    switch (type) {
      case MistakeType.misspelling:
        return highlightStyle.misspellingMistakeColor;
      case MistakeType.typographical:
        return highlightStyle.typographicalMistakeColor;
      case MistakeType.grammar:
        return highlightStyle.grammarMistakeColor;
      case MistakeType.uncategorized:
        return highlightStyle.uncategorizedMistakeColor;
      case MistakeType.nonConformance:
        return highlightStyle.nonConformanceMistakeColor;
      case MistakeType.style:
        return highlightStyle.styleMistakeColor;
      case MistakeType.other:
        return highlightStyle.otherMistakeColor;
    }
  }

  OverlayEntry _createTooltip(BuildContext context, Offset offset, Mistake mistake, String mistakeText) {
    final Color color = _getMistakeColor(mistake.type);
    Iterable<String> replacements = mistake.replacements.take(15);
    return OverlayEntry(
      builder: (context) =>
          Positioned(
            left: offset.dx - 100,
            width: 200,
            bottom: (context.height - offset.dy) ~/ 60 * 60 + 60,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.properSurface,
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
                            hoverColor: color.withOpacity(0.2),
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
            backgroundColor: _getMistakeColor(mistake.type).withOpacity(highlightStyle.backgroundOpacity),
            decoration: highlightStyle.decoration,
            decorationColor: _getMistakeColor(mistake.type),
            decorationThickness: highlightStyle.mistakeLineThickness,
          );

          final prevMistakeEnd = i == 0 ? 0 : mistakes[i - 1].endOffset - offset;
          final leadingNonMistakeText = chunk.substring(prevMistakeEnd, mistakeStart);
          if (leadingNonMistakeText.isNotEmpty) spans.add(TextSpan(text: leadingNonMistakeText, style: style));

          spans.add(
            TextSpan(
              text: mistakeText,
              style: mistakeStyle,
              onEnter: (event) {
                if (_mistakeTooltip != null) {
                  _mistakeTooltip!.remove();
                }
                _mistakeTooltip = _createTooltip(context,
                    Offset(event.position.dx - ns.widthChatListLeft(context), event.position.dy), mistake, mistakeText);
                Overlay.of(context).insert(_mistakeTooltip!);
              },
            ),
          );

          if (i == mistakes.length - 1) {
            final nextMistakeStart = i == mistakes.length - 1 ? chunk.length : mistakes[i + 1].offset - offset;
            final trailingNonMistakeText = chunk.substring(mistakeEnd, nextMistakeStart);
            if (trailingNonMistakeText.isNotEmpty) spans.add(TextSpan(text: trailingNonMistakeText, style: style));
          }
        }
        return TextSpan(children: spans);
      }
    }
    return TextSpan(text: chunk, style: style);
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
  MentionTextEditingController({
    super.text,
    super.focusNode,
    this.mentionables = const <Mentionable>[],
  });

  static const escapingChar = "￼";
  static const zeroWidthSpace = "​";
  static final escapingRegex = RegExp('$escapingChar\\d+$escapingChar');

  List<Mentionable> mentionables;

  void processMentions() => _processMentions(text);

  void _processMentions(String text) {
    final matches = escapingRegex.allMatches(text);
    Iterable<int> mentionedIndices = matches.map((m) => int.tryParse(text.substring(m.start + 1, m.end - 1))).whereNotNull();
    mentionables.forEachIndexed((i, m) {
      if (!mentionedIndices.contains(i)) {
        m.customDisplayName = null;
      }
    });
  }

  void addMention(String candidate, Mentionable mentionable) {
    final indexSelection = selection.base.offset;
    final atIndex = text.substring(0, indexSelection).lastIndexOf("@");
    final index = mentionables.indexOf(mentionable);
    if (index == -1 || atIndex == -1) return;
    List<String> textParts = [
      text.substring(0, atIndex),
      text.substring(atIndex, indexSelection),
      text.substring(indexSelection)
    ];
    final addSpace = !textParts[2].startsWith(" ");
    final replacement = "$escapingChar$index$escapingChar${addSpace ? " " : ""}";
    text = textParts[0] + textParts[1].replaceFirst(candidate, replacement) + textParts[2];
    selection = TextSelection.collapsed(offset: indexSelection - candidate.length + replacement.length);
    processMentions();
  }

  String get cleansedText {
    final res = escapingRegex.allMatches(text);
    List<String> textSplit = <String>[];
    int start = 0;
    int end = 0;
    int index = 0;
    while (index < res.length) {
      RegExpMatch elem = res.elementAt(index++);
      end = elem.start;
      if (start != end) {
        textSplit.add(text.substring(start, end));
      }
      textSplit.add(text.substring(elem.start, elem.start + 1));
      textSplit.add(text.substring(elem.start + 1, elem.end - 1));
      textSplit.add(text.substring(elem.end - 1, elem.end));
      start = elem.end;
    }
    if (start < text.length) {
      textSplit.add(text.substring(start));
    }
    bool flag = false;
    return textSplit.map((word) {
      if (word == escapingChar) {
        flag = !flag;
        return "";
      }
      int? index = flag ? int.tryParse(word) : null;
      if (index != null) {
        final mention = mentionables[index];
        return mention.displayName;
      }
      return word;
    }).join();
  }

  static List<String> splitText(String text) {
    final res = escapingRegex.allMatches(text);
    List<String> textSplit = <String>[];
    int start = 0;
    int end = 0;
    int index = 0;
    while (index < res.length) {
      RegExpMatch elem = res.elementAt(index++);
      end = elem.start;
      if (start != end) {
        textSplit.add(text.substring(start, end));
      }
      textSplit.add(text.substring(elem.start, elem.start + 1));
      textSplit.add(text.substring(elem.start + 1, elem.end - 1));
      textSplit.add(text.substring(elem.end - 1, elem.end));
      start = elem.end;
    }
    if (start < text.length) {
      textSplit.add(text.substring(start));
    }
    return textSplit;
  }

  @override
  set value(TextEditingValue newValue) {
    String newText = newValue.text;
    int newOffset = newValue.selection.start;

    // Need fewer chars for anything bad to happen
    if (newText.length < text.length) {
      // Search for the new state in the old state starting from the old selection's end
      String textSearchPart = text.substring(selection.end);
      int indexInNew = textSearchPart == "" || newValue.selection.end == -1
          ? newText.length
          : newText.indexOf(textSearchPart, newValue.selection.end);
      if (indexInNew == -1) {
        // This means that the cursor was behind the deleted portion (user used delete key probably)
        textSearchPart = text.substring(0, selection.start);
        indexInNew = textSearchPart == "" ? 0 : newText.indexOf(textSearchPart);
        indexInNew += textSearchPart.length;
      }

      indexInNew = min(indexInNew, newText.length);

      if (indexInNew != -1) {
        // Just in case
        bool deletingBadMention = false;

        String textPart1 = newText.substring(0, indexInNew);
        String textPart2 = newText.substring(indexInNew);

        if (MentionTextEditingController.escapingChar.allMatches(textPart1).length % 2 != 0) {
          final badMentionIndex = textPart1.lastIndexOf(MentionTextEditingController.escapingChar);
          textPart1 = textPart1.substring(0, badMentionIndex);
          deletingBadMention = true;
        }
        if (MentionTextEditingController.escapingChar.allMatches(textPart2).length % 2 != 0) {
          final badMentionIndex = textPart2.indexOf(MentionTextEditingController.escapingChar);
          textPart2 = textPart2.substring(badMentionIndex + 1);
          deletingBadMention = true;
        }

        if (deletingBadMention) {
          newText = textPart1 + textPart2;
          newOffset = textPart1.length;
          _processMentions(newText);

          newValue = newValue.copyWith(
            text: newText,
            selection: TextSelection.collapsed(offset: newOffset),
          );
        }
      }
    }

    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textSplit = splitText(text);
    bool flag = false;
    int mentionIndexLength = 0;
    return TextSpan(
      children: textSplit.mapIndexed((idx, word) {
        int offset = textSplit
            .slice(0, idx)
            .join("")
            .length;

        if (word == escapingChar) flag = !flag;
        int? index = flag ? int.tryParse(word) : null;
        if (index != null) {
          final mention = mentionables[index];
          mentionIndexLength = "$index".length;
          // Mandatory WidgetSpan so that it takes the appropriate char number.
          return WidgetSpan(
            child: Listener(
              onPointerDown: (PointerDownEvent e) {
                if (selection.isCollapsed && e.buttons == 2) {
                  // Right click
                  selection = TextSelection(baseOffset: offset - 1, extentOffset: offset + word.length + 1);
                }
              },
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) =>
                    LinearGradient(
                      colors: <Color>[
                        context.theme.colorScheme.primary.darkenPercent(20),
                        context.theme.colorScheme.primary.lightenPercent(20)
                      ],
                    ).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                child: Text(
                  mention.displayName,
                  style: style!.copyWith(fontWeight: FontWeight.bold).apply(heightFactor: 1.1),
                ),
              ),
            ),
          );
        }
        if (word == escapingChar) {
          String text = zeroWidthSpace;
          if (mentionIndexLength > 1) {
            text = List.filled(mentionIndexLength, zeroWidthSpace).join();
            mentionIndexLength = 0;
          }
          return TextSpan(text: text, style: style);
        }

        // Anything beyond this point is not a mention. So fallback to original style.
        return buildMistakeTextSpans(
          context: context,
          chunk: word.replaceAll(escapingChar, zeroWidthSpace),
          offset: offset,
          style: style,
        );
      }).toList(),
    );
  }
}
