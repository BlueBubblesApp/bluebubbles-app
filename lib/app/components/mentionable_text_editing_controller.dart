import "package:bluebubbles/helpers/helpers.dart";
import "package:bluebubbles/models/io/handle.dart";
import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:get/get.dart";

class Mentionable {
  Mentionable({required this.handle});

  final Handle handle;
  String? customDisplayName;

  String get displayName => customDisplayName ?? handle.displayName;

  String get address => handle.address;

  String buildMention() => '<mention>$displayName</mention>';

  bool match(String search) => address.toLowerCase().contains(search.toLowerCase());

  @override
  bool operator ==(Object other) => identical(this, other) || other is Mentionable && runtimeType == other.runtimeType && address == other.address;

  @override
  int get hashCode => address.hashCode;
}


class MentionTextEditingController extends TextEditingController {
  MentionTextEditingController({String? text, this.mentionables=const <Mentionable>[]}) : super(text: text);
  static const escapingChar = "￼";
  static const zeroWidthSpace = "​";
  static final escapingRegex = RegExp('$escapingChar\\d+$escapingChar');

  List<Mentionable> mentionables;

  // mention cache
  Iterable<int> mentionedIndices = <int>[];

  void processMentions() {
    final matches = escapingRegex.allMatches(text);
    mentionedIndices = matches.map((m) => int.tryParse(text.substring(m.start + 1, m.end - 1))).whereNotNull();
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
    List<String> textParts = [text.substring(0, atIndex), text.substring(atIndex, indexSelection), text.substring(indexSelection)];
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

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
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
    return TextSpan(
      style: style,
      children: textSplit.mapIndexed((idx, word) {
        if (word == escapingChar) flag = !flag;
        int? index = flag ? int.tryParse(word) : null;
        if (index != null) {
          final mention = mentionables[index];
          // Mandatory WidgetSpan so that it takes the appropriate char number.
          return WidgetSpan(
            child: Listener(
              onPointerDown: (PointerDownEvent e) {
                if (selection.isCollapsed && e.buttons == 2) { // Right click
                  final start = textSplit.slice(0, idx).join("").length;
                  selection = TextSelection(baseOffset: start - 1, extentOffset: start + word.length + 1);
                }
              },
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  colors: <Color>[context.theme.colorScheme.primary.darkenPercent(20), context.theme.colorScheme.primary.lightenPercent(20)],
                ).createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: Text(
                  mention.displayName,
                  style: style!.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        }
        if (word == escapingChar) {
          return TextSpan(text: zeroWidthSpace, style: style);
        }
        return TextSpan(text: word.replaceAll(escapingChar, zeroWidthSpace), style: style);
      }).toList(),
    );
  }
}
