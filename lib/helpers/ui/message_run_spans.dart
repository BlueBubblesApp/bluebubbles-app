import 'package:bluebubbles/database/global/attributed_body.dart';
import 'package:bluebubbles/models/text_entity_match.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Renders intersections of attributed runs and detected entities without changing their UTF-16 offsets.
/// Mentions come from the runs and take priority over detected links/entities.
List<InlineSpan> buildMessageRunSpans({
  required String text,
  required List<Run> runs,
  required TextStyle style,
  List<TextEntityMatch> entities = const [],
  void Function(TextEntityMatch entity, String text)? onTap,
  List<TextSpan> Function(String text, TextStyle style, TapGestureRecognizer? recognizer)? buildText,
}) {
  bool valid(int start, int end) => start >= 0 && end > start && end <= text.length;
  final validRuns = runs.where((r) => r.range.length == 2 && valid(r.range[0], r.range[0] + r.range[1])).toList();
  final matches = [
    for (final run in validRuns)
      if (run.hasMention)
        TextEntityMatch('mention', run.range[0], run.range[0] + run.range[1], [run.attributes!.mention]),
    ...entities.where((e) => valid(e.start, e.end)),
  ];
  final boundaries = <int>{0, text.length};
  for (final run in validRuns) {
    boundaries.addAll([run.range[0], run.range[0] + run.range[1]]);
  }
  for (final match in matches) {
    boundaries.addAll([match.start, match.end]);
  }
  final offsets = boundaries.toList()..sort();
  final spans = <InlineSpan>[];
  final recognizers = <TextEntityMatch, TapGestureRecognizer>{};
  for (var i = 0; i + 1 < offsets.length; i++) {
    final start = offsets[i];
    final end = offsets[i + 1];
    final attributes = validRuns
        .where((r) => r.range[0] <= start && r.range[0] + r.range[1] >= end)
        .map((r) => r.attributes);
    TextEntityMatch? entity;
    for (final match in matches) {
      if (match.start <= start && match.end >= end) {
        entity = match;
        break;
      }
    }
    final decorations = [
      if (style.decoration != null) style.decoration!,
      if (attributes.any((a) => a?.isUnderlined ?? false) || entity != null && entity.type != 'mention')
        TextDecoration.underline,
      if (attributes.any((a) => a?.isStrikethrough ?? false)) TextDecoration.lineThrough,
    ];
    final segmentStyle = style.copyWith(
      fontWeight: attributes.any((a) => a?.isBold ?? false) || entity?.type == 'mention' ? FontWeight.bold : null,
      fontStyle: attributes.any((a) => a?.isItalic ?? false) ? FontStyle.italic : null,
      decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
    );
    final match = entity;
    final recognizer = match == null || onTap == null
        ? null
        : recognizers.putIfAbsent(
            match,
            () => TapGestureRecognizer()..onTap = () => onTap(match, text.substring(match.start, match.end)),
          );
    final segment = text.substring(start, end);
    spans.addAll(
      buildText?.call(segment, segmentStyle, recognizer) ??
          [TextSpan(text: segment, style: segmentStyle, recognizer: recognizer)],
    );
  }
  return spans;
}
