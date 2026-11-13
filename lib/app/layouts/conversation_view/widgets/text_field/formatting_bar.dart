import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/database/global/attributed_body.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Formatting and text effect controls shown above the composer input while text is selected or formatting is
/// active.
class FormattingBar extends StatelessWidget {
  const FormattingBar({super.key, required this.controller, required this.focusNode});

  final MentionTextEditingController controller;
  final FocusNode focusNode;

  static const _styles = [
    ('B', TextStyle(fontWeight: FontWeight.bold), 'bold'),
    ('I', TextStyle(), 'italic'),
    ('U', TextStyle(decoration: TextDecoration.underline), 'underline'),
    ('S', TextStyle(decoration: TextDecoration.lineThrough, decorationThickness: 2.5), 'strikethrough'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Also up while typing would carry formatting forward, or new text picks it up unseen
        if (controller.selection.isCollapsed && !controller.hasActiveFormatting) return const SizedBox.shrink();
        final colors = context.theme.colorScheme;
        final effect = controller.selectionEffect;

        Widget button({required Widget child, required bool active, required VoidCallback onPressed}) {
          return TextButton(
            onPressed: () {
              onPressed();
              focusNode.requestFocus();
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(32, 30),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: active ? colors.primary.withValues(alpha: 0.18) : null,
              foregroundColor: active ? colors.primary : colors.onSurface,
            ),
            child: child,
          );
        }

        // Tapping the bar must not count as tapping away from the field
        return TextFieldTapRegion(
          child: ExcludeFocus(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  for (final (label, labelStyle, style) in _styles)
                    button(
                      active: controller.selectionHas(MentionTextEditingController.styleAttributes[style]!, 1),
                      onPressed: () => controller.toggleStyle(MentionTextEditingController.styleAttributes[style]!),
                      child: Text(label, style: labelStyle),
                    ),
                  Container(
                    width: 1,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: colors.outlineVariant,
                  ),
                  for (final MapEntry(key: id, value: name) in Attributes.textEffectNames.entries)
                    button(
                      active: effect == id,
                      onPressed: () => controller.setEffect(effect == id ? null : id),
                      child: Text(name.capitalize!),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
