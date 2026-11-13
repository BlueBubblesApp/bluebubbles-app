import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/text/run_text_effects.dart';
import 'package:bluebubbles/database/global/attributed_body.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Swaps the keyboard for [TextFormattingPanel], keeping the field focused so the selection stays and edits apply.
void openTextFormattingPanel(ConversationViewController controller) {
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  final keyboard = view == null ? 0.0 : view.viewInsets.bottom / view.devicePixelRatio;
  // The panel takes the keyboard's height, so the field stays put
  if (keyboard > 100) controller.textFormattingPanelHeight = keyboard;
  SystemChannels.textInput.invokeMethod('TextInput.hide');
  controller.showTextFormattingPanel.value = true;
}

/// Bold, italic, underline, and strikethrough over a grid of [TextEffectGrid], in the keyboard's place (mobile).
class TextFormattingPanel extends StatelessWidget {
  const TextFormattingPanel({super.key, required this.controller, required this.height});

  final MentionTextEditingController controller;
  final double height;

  static const styles = [
    ('B', TextStyle(fontWeight: FontWeight.bold), 'bold'),
    ('I', TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w600), 'italic'),
    ('U', TextStyle(decoration: TextDecoration.underline), 'underline'),
    ('S', TextStyle(decoration: TextDecoration.lineThrough), 'strikethrough'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colorScheme;
    // Taps here must not count as tapping away from the field
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Column(
                children: [
                  Row(
                    children: [
                      for (final (label, style, name) in styles)
                        Expanded(
                          child: _StyleToggle(
                            label: label,
                            style: style,
                            active: controller.selectionHas(MentionTextEditingController.styleAttributes[name]!, 1),
                            onPressed: () =>
                                controller.toggleStyle(MentionTextEditingController.styleAttributes[name]!),
                            colors: colors,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(child: TextEffectGrid(controller: controller)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StyleToggle extends StatelessWidget {
  const _StyleToggle({
    required this.label,
    required this.style,
    required this.active,
    required this.onPressed,
    required this.colors,
  });

  final String label;
  final TextStyle style;
  final bool active;
  final VoidCallback onPressed;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: active ? colors.primary.withValues(alpha: 0.18) : null,
        foregroundColor: active ? colors.primary : colors.onSurface,
      ),
      child: Text(label, style: style.copyWith(fontSize: 18)),
    );
  }
}

/// The text effects as tiles, each showing its name in its effect. Tapping one puts it on the selection, or takes it
/// off when it's already there.
class TextEffectGrid extends StatefulWidget {
  const TextEffectGrid({super.key, required this.controller, this.onPicked, this.tileHeight});

  final MentionTextEditingController controller;
  final VoidCallback? onPicked;

  /// Fixed tile height for a popover. Null fills the space given, as the keyboard-sized panel does.
  final double? tileHeight;

  @override
  State<TextEffectGrid> createState() => _TextEffectGridState();
}

class _TextEffectGridState extends State<TextEffectGrid> with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(vsync: this, duration: RunTextEffects.effectDuration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _loop.stop() : _loop.repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colorScheme;
    final bubbleText = context.theme.extension<BubbleText>()!.bubbleText;
    final textStyle = bubbleText.copyWith(fontSize: (bubbleText.fontSize ?? 16) * 1.4);
    final bubbleColors = context.theme.extension<BubbleColors>();
    final effects = Attributes.textEffectNames.entries.toList();
    final rows = (effects.length / 2).ceil();
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final selected = widget.controller.selectionEffect;
        // Effects only go on selected text
        final enabled = !widget.controller.selection.isCollapsed;
        Widget tile(int id, String name) {
          final label = name.capitalize!;
          final active = selected == id;
          // Each preview is a received bubble; the chosen one is outlined, since they all share its color
          final bubble = Material(
            color: bubbleColors?.receivedBubbleColor ?? colors.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: active ? BorderSide(color: colors.primary, width: 2.5) : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: !enabled
                  ? null
                  : () {
                      widget.controller.setEffect(active ? null : id);
                      widget.onPicked?.call();
                    },
              child: Center(
                child: RunTextEffects(
                  runs: [
                    Run(
                      range: [0, label.length],
                      attributes: Attributes(rawAttributes: {MentionTextEditingController.effectAttribute: id}),
                    ),
                  ],
                  animation: _loop,
                  child: RichText(
                    text: TextSpan(
                      text: label,
                      style: textStyle.copyWith(color: bubbleColors?.onReceivedBubbleColor ?? colors.onSurface),
                    ),
                  ),
                ),
              ),
            ),
          );
          return enabled ? bubble : Opacity(opacity: 0.4, child: bubble);
        }

        Widget row(int index) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, effect) in effects.skip(index * 2).take(2).indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: tile(effect.key, effect.value)),
            ],
          ],
        );

        return Column(
          mainAxisSize: widget.tileHeight == null ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < rows; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              widget.tileHeight == null ? Expanded(child: row(i)) : SizedBox(height: widget.tileHeight, child: row(i)),
            ],
          ],
        );
      },
    );
  }
}
