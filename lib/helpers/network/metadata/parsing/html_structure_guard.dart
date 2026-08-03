/// Rejects documents whose nesting would blow the stack during traversal.
///
/// `package:html`'s tree builder is iterative, but the traversal the parsers
/// rely on — `getElementsByTagName`, `querySelectorAll`, `Element.text` —
/// recurses over children. A body of 512KB can encode roughly 85,000 nested
/// `<div>`s, which is enough stack frames to crash the app from an incoming
/// text message.
///
/// This is deliberately a scan of the *raw markup*, before parsing, because
/// measuring the depth of an already-built DOM requires the very traversal we
/// are trying to protect. The scan is a single linear pass with no recursion.
abstract final class HtmlStructureGuard {
  /// Maximum tag nesting depth accepted.
  ///
  /// Real pages rarely exceed ~50; even pathological CMS output stays under
  /// 150. 256 leaves generous headroom while staying far below the stack
  /// depth a recursive traversal can survive.
  static const int maxDepth = 256;

  /// Elements that never have a closing tag, so they must not increment depth.
  /// Without this, a page with a few thousand `<img>` tags in a row would look
  /// pathologically nested.
  static const Set<String> _voidElements = {
    'area',
    'base',
    'basefont',
    'bgsound',
    'br',
    'col',
    'embed',
    'frame',
    'hr',
    'img',
    'input',
    'keygen',
    'link',
    'meta',
    'param',
    'source',
    'track',
    'wbr',
  };

  /// Elements whose content is raw text and may legitimately contain `<`.
  static const Set<String> _rawTextElements = {'script', 'style', 'textarea', 'title'};

  /// Whether [html] is safe to hand to the parser.
  static bool isSafe(String html) => maxNestingDepth(html) <= maxDepth;

  /// The deepest tag nesting in [html].
  ///
  /// Stops early once [maxDepth] is exceeded, so a pathological document costs
  /// only as much as the prefix needed to prove it.
  static int maxNestingDepth(String html) {
    var depth = 0;
    var deepest = 0;
    var i = 0;
    final length = html.length;

    while (i < length) {
      final open = html.indexOf('<', i);
      if (open == -1 || open + 1 >= length) break;

      final next = html.codeUnitAt(open + 1);

      // Comments, doctypes and processing instructions: skip to '>'.
      if (next == 0x21 || next == 0x3F) {
        final close = html.indexOf('>', open + 1);
        if (close == -1) break;
        i = close + 1;
        continue;
      }

      // Closing tag.
      if (next == 0x2F) {
        final close = html.indexOf('>', open + 2);
        if (close == -1) break;
        if (depth > 0) depth--;
        i = close + 1;
        continue;
      }

      if (!_isNameStart(next)) {
        i = open + 1;
        continue;
      }

      final close = html.indexOf('>', open + 1);
      if (close == -1) break;

      final tag = _tagName(html, open + 1, close);
      final selfClosing = close > open + 1 && html.codeUnitAt(close - 1) == 0x2F;

      if (_rawTextElements.contains(tag)) {
        // Jump past the raw-text content so its `<` characters are not read as
        // markup — `if (a < b)` inside a script would otherwise look like a tag.
        final end = _indexOfClosing(html, tag, close + 1);
        i = end == -1 ? length : end;
        continue;
      }

      if (!selfClosing && !_voidElements.contains(tag)) {
        depth++;
        if (depth > deepest) {
          deepest = depth;
          if (deepest > maxDepth) return deepest;
        }
      }

      i = close + 1;
    }

    return deepest;
  }

  static bool _isNameStart(int unit) =>
      (unit >= 0x61 && unit <= 0x7A) || (unit >= 0x41 && unit <= 0x5A); // a-z A-Z

  static String _tagName(String html, int start, int limit) {
    var end = start;
    while (end < limit) {
      final unit = html.codeUnitAt(end);
      final isAlpha = (unit >= 0x61 && unit <= 0x7A) || (unit >= 0x41 && unit <= 0x5A);
      final isDigit = unit >= 0x30 && unit <= 0x39;
      if (!isAlpha && !isDigit) break;
      end++;
    }
    return html.substring(start, end).toLowerCase();
  }

  /// Index just past the matching `</tag ... >`, or -1.
  ///
  /// Matched case-insensitively without allocating a lowercased copy of the
  /// document, since `</SCRIPT>` is as valid as `</script>`.
  static int _indexOfClosing(String html, String tag, int from) {
    var i = from;
    while (i < html.length) {
      final found = html.indexOf('<', i);
      if (found == -1 || found + 1 >= html.length) return -1;

      if (html.codeUnitAt(found + 1) != 0x2F) {
        i = found + 1;
        continue;
      }

      final name = _tagName(html, found + 2, html.length);
      if (name != tag) {
        i = found + 2;
        continue;
      }

      final close = html.indexOf('>', found + 2 + name.length);
      return close == -1 ? -1 : close + 1;
    }
    return -1;
  }
}
