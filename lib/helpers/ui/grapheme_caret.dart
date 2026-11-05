import 'package:flutter/services.dart' show TextEditingValue, TextSelection;

/// Returns [offset] moved forward to just past a UTF-16 surrogate pair when it falls between the
/// pair's two code units; otherwise returns it unchanged. The result is never inside a pair.
///
/// We snap to the end of the pair (offset + 1) rather than the start (offset - 1) so the caret
/// lands *after* the emoji. In RTL a tap aiming for the spot after a trailing emoji (visually to
/// its left) often lands mid-glyph; snapping to the start would yank the caret before the emoji,
/// where backspace deletes the wrong character (e.g. the preceding space) and the emoji can never
/// be removed. Snapping past the pair keeps a tap on a trailing emoji able to backspace it, and is
/// still a clean boundary so the next edit cannot split the pair. offset + 1 is always valid here:
/// a low surrogate at [offset] guarantees offset < text.length.
int _offsetOffSurrogatePair(String text, int offset) {
  if (offset <= 0 || offset >= text.length) return offset;
  final int prev = text.codeUnitAt(offset - 1);
  final int next = text.codeUnitAt(offset);
  final bool insidePair = prev >= 0xD800 && prev <= 0xDBFF && next >= 0xDC00 && next <= 0xDFFF;
  return insidePair ? offset + 1 : offset;
}

/// Snaps both endpoints of [value]'s selection off any UTF-16 surrogate-pair interior.
///
/// A caret left between the two halves of an emoji's surrogate pair lets the next edit split the
/// pair into lone surrogates. On Android the text-input channel then encodes each lone half as
/// `?` (the user-visible "??" corruption), and the text painter throws
/// "string is not well-formed UTF-16". This is the app-side equivalent of the framework fix in
/// flutter/flutter#188713 (PR flutter/flutter#188719); applying it in the compose controller fixes
/// the corruption without requiring a Flutter SDK upgrade, and is scoped to this field only.
TextEditingValue snapSelectionOffSurrogatePairs(TextEditingValue value) {
  final TextSelection selection = value.selection;
  if (!selection.isValid) return value;
  final String text = value.text;
  final int base = _offsetOffSurrogatePair(text, selection.baseOffset);
  final int extent = _offsetOffSurrogatePair(text, selection.extentOffset);
  if (base == selection.baseOffset && extent == selection.extentOffset) return value;
  return value.copyWith(selection: selection.copyWith(baseOffset: base, extentOffset: extent));
}
