import 'package:flutter/material.dart';

/// Rebuilds [builder] with the current text direction of [controller], but ONLY
/// when that direction actually flips — never on plain keystroke or selection
/// changes.
///
/// A `ValueListenableBuilder<TextEditingValue>` on the controller would rebuild
/// the child on every value change, and since the selection is part of the value,
/// that rebuild lands mid-cursor-drag and cancels the gesture (the caret "lets go"
/// after one step). Listening for direction changes only keeps the child
/// (e.g. a TextField/EditableText) stable during normal editing.
class TextDirectionBuilder extends StatefulWidget {
  const TextDirectionBuilder({super.key, required this.controller, required this.builder});

  final TextEditingController controller;
  final Widget Function(BuildContext context, TextDirection direction) builder;

  @override
  State<TextDirectionBuilder> createState() => _TextDirectionBuilderState();
}

class _TextDirectionBuilderState extends State<TextDirectionBuilder> {
  late TextDirection _direction = getTextDirection(widget.controller.text);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    final next = getTextDirection(widget.controller.text);
    if (next != _direction) setState(() => _direction = next);
  }

  @override
  void didUpdateWidget(TextDirectionBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _onChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _direction);
}

/// Upper bound on [_directionCache]. A conversation list renders on the order of
/// 60 tiles (a title and a subtitle each) and a conversation view on the order of
/// 100 message parts, so 512 holds a full working set with headroom while
/// bounding how many strings the cache keeps alive.
const int _directionCacheCapacity = 512;

/// Memoizes [getTextDirection]. Safe with no invalidation: the direction is a
/// pure function of the text, so an entry cannot go stale for its own key.
///
/// A Dart map literal is insertion-ordered, so the oldest key is `keys.first` and
/// eviction is O(1). Deliberately NOT a move-to-end LRU: promoting a key on every
/// hit costs a `remove` plus a re-insert, measured at 34 ns/hit against the 13 ns
/// scan it would replace for ordinary text — a true LRU makes the common case
/// slower than having no cache at all. Insertion-order eviction keeps the hit
/// path to a single lookup (~6-11 ns).
final Map<String, TextDirection> _directionCache = <String, TextDirection>{};

/// Clears the memo table. Tests only — it never needs invalidating in production
/// because [_detectTextDirection] is pure.
@visibleForTesting
void clearTextDirectionCache() => _directionCache.clear();

/// Number of memoized entries. Tests only.
@visibleForTesting
int get textDirectionCacheLength => _directionCache.length;

/// The bound enforced on the memo table. Tests only.
@visibleForTesting
int get textDirectionCacheCapacity => _directionCacheCapacity;

/// Whether [text] is currently memoized. Tests only — lets the eviction test
/// assert *which* key was dropped, not merely how many remain.
@visibleForTesting
bool textDirectionCacheContains(String text) => _directionCache.containsKey(text);

/// Detects the paragraph direction of [text] from its first strongly-directional
/// character (UAX#9 "first strong" heuristic), so RTL languages (Farsi, Arabic,
/// Hebrew) render and align correctly.
///
/// Memoized, because the message widgets call this from inside `build` — the
/// `RichText` in a message bubble, a reply bubble, the send animation and the
/// conversation tile — so it re-runs on every rebuild, not only when the text
/// changes. Detection early-exits on the first strongly-directional character,
/// which is cheap for ordinary text (~13 ns), but text made only of neutral
/// characters (digits, punctuation, an emoji-only message) has no such character
/// and is scanned to the end: ~640 ns for 200 units, ~1150 ns for an emoji-only
/// message. The memo turns that into one map lookup.
TextDirection getTextDirection(String? text) {
  if (text == null || text.isEmpty) return TextDirection.ltr;
  final TextDirection? cached = _directionCache[text];
  if (cached != null) return cached;
  final TextDirection direction = _detectTextDirection(text);
  _directionCache[text] = direction;
  if (_directionCache.length > _directionCacheCapacity) {
    _directionCache.remove(_directionCache.keys.first);
  }
  return direction;
}

/// The uncached detection itself.
///
/// Implemented over runes rather than intl's [Bidi.startsWithRtl], which
/// misclassifies leading emoji as LTR (their UTF-16 surrogates fall inside its
/// LTR character ranges).
TextDirection _detectTextDirection(String text) {
  for (final rune in text.runes) {
    // Strong RTL: Hebrew, Arabic, Syriac, Thaana, NKo, Samaritan...,
    // Arabic/Hebrew presentation forms, and the historic/supplemental RTL planes.
    if ((rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF) ||
        (rune >= 0x10800 && rune <= 0x10FFF) ||
        (rune >= 0x1E800 && rune <= 0x1EFFF)) {
      return TextDirection.rtl;
    }
    // Strong LTR: Latin letters and the LTR script blocks below/above the RTL
    // ranges. Everything else (digits, punctuation, emoji, symbols) is treated
    // as neutral and skipped.
    if ((rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        (rune >= 0x00C0 && rune <= 0x058F) ||
        (rune >= 0x0900 && rune <= 0x1FFF) ||
        (rune >= 0x2C00 && rune <= 0xD7FF)) {
      return TextDirection.ltr;
    }
  }
  return TextDirection.ltr;
}
