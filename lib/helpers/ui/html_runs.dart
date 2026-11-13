import 'package:bluebubbles/database/global/attributed_body.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:pasteboard/pasteboard.dart';
import 'package:universal_io/io.dart';

/// The clipboard's rich copy as HTML for [htmlRuns]. On Android most apps copy styled text rather than an HTML clip,
/// which pasteboard can't read, so the platform side converts either to HTML.
Future<String?> clipboardHtml() => Platform.isAndroid ? MethodChannelSvc.actions.clipboardHtml() : Pasteboard.html;

const _bold = 1, _italic = 2, _underline = 4, _strikethrough = 8;
const _attributes = {
  _bold: '__kIMTextBoldAttributeName',
  _italic: '__kIMTextItalicAttributeName',
  _underline: '__kIMTextUnderlineAttributeName',
  _strikethrough: '__kIMTextStrikethroughAttributeName',
};

/// Bold, italic, underline, and strikethrough runs over [plain], from the HTML another app copied along with it
/// (Windows' CF_HTML, header and all, or Android's HTML clip). The HTML spells whitespace differently from [plain],
/// so its styles are matched to [plain]'s characters ignoring whitespace.
List<Run> htmlRuns(String html, String plain) {
  const startMarker = '<!--StartFragment-->';
  final start = html.indexOf(startMarker);
  final end = html.indexOf('<!--EndFragment-->');
  if (start != -1 && end > start) html = html.substring(start + startMarker.length, end);

  final chars = <(String, int)>[];
  void walk(dom.Node node, int style) {
    if (node is dom.Text) {
      for (final rune in node.text.runes) {
        final char = String.fromCharCode(rune);
        if (char.trim().isNotEmpty) chars.add((char, style));
      }
      return;
    }
    if (node is dom.Element) {
      if (const {'script', 'style', 'head', 'title'}.contains(node.localName)) return;
      style = _styleOf(node, style);
    }
    for (final child in node.nodes) {
      walk(child, style);
    }
  }

  walk(html_parser.parseFragment(html), 0);
  if (chars.every((c) => c.$2 == 0)) return const [];

  final styles = List<int?>.filled(plain.length, null);
  var at = 0;
  for (final (char, style) in chars) {
    // A character only one side has (a bullet, a converted dash) is skipped rather than throwing the rest off
    var found = at;
    while (found < plain.length && found - at < 8 && !plain.startsWith(char, found)) {
      found++;
    }
    if (found >= plain.length || !plain.startsWith(char, found)) continue;
    styles.fillRange(found, found + char.length, style);
    at = found + char.length;
  }
  // Whitespace between two characters of one style belongs to it, so "two words" stays one run
  final after = List<int?>.filled(plain.length + 1, null);
  for (var i = plain.length - 1; i >= 0; i--) {
    after[i] = styles[i] ?? after[i + 1];
  }
  int? before;
  for (var i = 0; i < plain.length; i++) {
    if (styles[i] != null) {
      before = styles[i];
    } else if (before != null && before == after[i]) {
      styles[i] = before;
    }
  }

  final runs = <Run>[];
  for (var i = 0; i < plain.length;) {
    final style = styles[i] ?? 0;
    var j = i + 1;
    while (j < plain.length && (styles[j] ?? 0) == style) {
      j++;
    }
    if (style != 0) {
      runs.add(Run(range: [i, j - i], attributes: Attributes(rawAttributes: {
        for (final MapEntry(:key, :value) in _attributes.entries)
          if (style & key != 0) value: 1,
      })));
    }
    i = j;
  }
  return runs;
}

int _styleOf(dom.Element element, int style) {
  switch (element.localName) {
    case 'b' || 'strong':
      style |= _bold;
    case 'i' || 'em':
      style |= _italic;
    case 'u' || 'ins':
      style |= _underline;
    case 's' || 'strike' || 'del':
      style |= _strikethrough;
  }
  final css = (element.attributes['style'] ?? '').toLowerCase().replaceAll(' ', '');
  // Google Docs wraps a whole copy in <b style="font-weight:normal">, so CSS overrides the tag
  final weight = RegExp(r'font-weight:([a-z0-9]+)').firstMatch(css)?.group(1);
  if (weight != null) {
    final number = int.tryParse(weight);
    final bold = weight == 'bold' || weight == 'bolder' || (number != null && number >= 600);
    style = bold ? style | _bold : style & ~_bold;
  }
  final fontStyle = RegExp(r'font-style:([a-z]+)').firstMatch(css)?.group(1);
  if (fontStyle != null) style = fontStyle == 'italic' || fontStyle == 'oblique' ? style | _italic : style & ~_italic;
  final decoration = RegExp(r'text-decoration(?:-line)?:([a-z\-]+)').firstMatch(css)?.group(1);
  if (decoration != null) {
    if (decoration.contains('none')) style &= ~(_underline | _strikethrough);
    if (decoration.contains('underline')) style |= _underline;
    if (decoration.contains('line-through')) style |= _strikethrough;
  }
  return style;
}
