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

/// Detects the paragraph direction of [text] from its first strongly-directional
/// character (UAX#9 "first strong" heuristic), so RTL languages (Farsi, Arabic,
/// Hebrew) render and align correctly.
///
/// Implemented over runes rather than intl's [Bidi.startsWithRtl], which
/// misclassifies leading emoji as LTR (their UTF-16 surrogates fall inside its
/// LTR character ranges).
TextDirection getTextDirection(String? text) {
  if (text == null) return TextDirection.ltr;
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
