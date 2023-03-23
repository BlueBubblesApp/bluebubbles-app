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
  MentionTextEditingController({String? text}) : super(text: text);
  final List<Mentionable> mentions = [];
  static const escapingChar = "￼";

  void addMention(String candidate, Mentionable mentionable) {
    final indexSelection = selection.base.offset;
    final textPart = text.substring(0, indexSelection);
    final indexInsertion = escapingChar.allMatches(textPart).length;
    mentions.insert(indexInsertion, mentionable);
    text = text.replaceAll(candidate, "$escapingChar ");
    selection = TextSelection.collapsed(offset: indexSelection - candidate.length + 2);
  }

  String get cleansedText {
    final regexp = RegExp('(?=$escapingChar)|(?<=$escapingChar)');
    final res = text.split(regexp);
    int i = 0;
    return res.map((e) {
      if (e == escapingChar && mentions.isNotEmpty) {
        final mention = mentions[i];
        i++;
        return mention.displayName;
      }
      return e;
    }).join();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final regexp = RegExp('(?=$escapingChar)|(?<=$escapingChar)');
    final res = text.split(regexp);
    int i = 0;
    return TextSpan(
      style: style,
      children: res.mapIndexed((idx, e) {
        if (e == escapingChar && mentions.isNotEmpty) {
          final mention = mentions[i];
          i++;
          // Mandatory WidgetSpan so that it takes the appropriate char number.
          return WidgetSpan(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (PointerDownEvent e) {
                if (selection.isCollapsed && e.buttons == 2) { // Right click
                  final start = res.slice(0, idx).join("").length;
                  selection = TextSelection(baseOffset: start, extentOffset: start + 1);
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
        return TextSpan(text: e, style: style);
      }).toList(),
    );
  }
}
