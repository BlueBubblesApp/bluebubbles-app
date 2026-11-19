import 'dart:io';

import 'package:bluebubbles/app/layouts/settings/pages/desktop/widgets/toast_preview_theme.dart';
import 'package:bluebubbles/services/backend/notifications/toast_button_images.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// A notification action as its button shows it: the image the Windows notification uses for a tapback or emoji, so
/// the preview can't drift from it, or the text of "Mark Read"
class ActionGlyph extends StatefulWidget {
  const ActionGlyph(this.value, {super.key, required this.size, this.style});
  final String value;
  final double size;
  final TextStyle? style;

  @override
  State<ActionGlyph> createState() => _ActionGlyphState();
}

class _ActionGlyphState extends State<ActionGlyph> {
  Future<String?>? _image;

  bool get _isLabel => widget.value == "Mark Read";

  @override
  void initState() {
    super.initState();
    if (!_isLabel) _image = ToastButtonImages.forAction(widget.value);
  }

  @override
  void didUpdateWidget(ActionGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _image = _isLabel ? null : ToastButtonImages.forAction(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLabel) {
      return Text(
        widget.value,
        style: widget.style?.copyWith(fontSize: widget.size),
        textAlign: TextAlign.center,
      );
    }
    return SizedBox.square(
      dimension: widget.size,
      child: FutureBuilder<String?>(
        future: _image,
        builder: (context, snapshot) => snapshot.data == null
            ? const SizedBox.shrink()
            : Image.file(File(snapshot.data!), filterQuality: FilterQuality.medium),
      ),
    );
  }
}

class NotificationActionButton extends StatefulWidget {
  const NotificationActionButton(
    this.action, {
    super.key,
    required this.toast,
    required this.width,
    required this.height,
    required this.glyphSize,
    required this.padding,
    required this.sends,
    required this.onRemove,
    required this.dragging,
  });
  final String action;
  final ToastPreviewTheme toast;
  final double width;
  final double height;
  final double glyphSize;

  /// Inside the button: on the preview it's the notification's own, which is what wraps "Mark Read"
  final EdgeInsets padding;
  final bool sends;
  final VoidCallback onRemove;
  final ValueListenable<bool> dragging;

  /// The action Add Action just added: only it grows in, not the buttons a drag rebuilds
  static String? justAdded;

  @override
  State<NotificationActionButton> createState() => _NotificationActionButtonState();
}

class _NotificationActionButtonState extends State<NotificationActionButton> {
  late final bool _growIn = widget.action == NotificationActionButton.justAdded;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    if (_growIn) NotificationActionButton.justAdded = null;
  }

  @override
  Widget build(BuildContext context) {
    final toast = widget.toast;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _growIn ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Stack(
          children: [
            Tooltip(
              message: "Drag to reorder",
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: widget.sends ? 1 : 0.4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: widget.width,
                  height: widget.height,
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: toast.border),
                    color: _hovered ? toast.border : toast.button,
                  ),
                  child: Center(
                    child: ActionGlyph(
                      widget.action,
                      size: widget.glyphSize,
                      style: context.textTheme.bodyMedium!.copyWith(color: toast.text),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: widget.dragging,
                builder: (context, dragging, child) => IgnorePointer(
                  ignoring: dragging,
                  child: AnimatedScale(
                    scale: dragging ? 0 : 1,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    child: child,
                  ),
                ),
                child: _RemoveButton(onTap: widget.onRemove),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoveButton extends StatefulWidget {
  const _RemoveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _hovered ? scheme.error : scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outline.withValues(alpha: 0.5)),
          ),
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: _hovered ? scheme.onError : scheme.onSurface),
            duration: const Duration(milliseconds: 150),
            builder: (context, color, _) => Icon(Icons.remove_rounded, size: 14, color: color),
          ),
        ),
      ),
    );
  }
}
