import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/text_effect_picker.dart';
import 'package:bluebubbles/database/global/attributed_body.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Formatting controls shown above the composer input while text is selected or formatting is active. Effects are
/// behind one button: on mobile it swaps the keyboard for [TextFormattingPanel], on desktop it opens a popover.
class FormattingBar extends StatelessWidget {
  const FormattingBar({super.key, required this.controller, required this.focusNode, this.conversation});

  final MentionTextEditingController controller;
  final FocusNode focusNode;

  /// Null in the chat creator, which has no keyboard panel and uses the popover.
  final ConversationViewController? conversation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // No formatting in a brand-new chat for now: chat/new sends its first message as plain text
        if (conversation == null) return const SizedBox.shrink();
        // Also up while typing would carry formatting forward, or new text picks it up unseen
        if (controller.selection.isCollapsed && !controller.hasActiveFormatting) return const SizedBox.shrink();
        final usePanel = !kIsDesktop && conversation != null;
        // The selection menu covers the bar here, so its "Text Effects" item opens the panel instead
        if (usePanel && !controller.selection.isCollapsed) return const SizedBox.shrink();
        final colors = context.theme.colorScheme;
        final effect = controller.selectionEffect;

        Widget button({required Widget child, required bool active, required VoidCallback? onPressed}) {
          return TextButton(
            onPressed: onPressed == null
                ? null
                : () {
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

        final effectsLabel = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 16),
            const SizedBox(width: 6),
            Text(effect == null ? 'Effects' : Attributes.textEffectNames[effect]!.capitalize!),
          ],
        );

        final bar = Row(
          children: [
            for (final (label, labelStyle, style) in TextFormattingPanel.styles)
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
            if (usePanel)
              button(
                active: effect != null,
                onPressed: () => openTextFormattingPanel(conversation!),
                child: effectsLabel,
              )
            else
              _EffectsPopoverButton(
                controller: controller,
                // Effects only go on selected text
                builder: (toggle) => button(
                  active: effect != null,
                  onPressed: controller.selection.isCollapsed ? null : toggle,
                  child: effectsLabel,
                ),
              ),
          ],
        );

        // Tapping the bar must not count as tapping away from the field
        final content = TextFieldTapRegion(
          child: ExcludeFocus(
            child: Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 0), child: bar),
          ),
        );
        // The panel has its own copy of these controls
        return usePanel
            ? Obx(() => conversation!.showTextFormattingPanel.value ? const SizedBox.shrink() : content)
            : content;
      },
    );
  }
}

/// The effects button on desktop, with its popover of [TextEffectGrid] above it.
class _EffectsPopoverButton extends StatefulWidget {
  const _EffectsPopoverButton({required this.controller, required this.builder});

  final MentionTextEditingController controller;
  final Widget Function(VoidCallback toggle) builder;

  @override
  State<_EffectsPopoverButton> createState() => _EffectsPopoverButtonState();
}

class _EffectsPopoverButtonState extends State<_EffectsPopoverButton> {
  final _popover = OverlayPortalController();
  final _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colorScheme;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _popover,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -8),
          child: Align(
            alignment: Alignment.bottomLeft,
            // In the field's tap group, so picking an effect doesn't unfocus it and lose the selection
            child: TextFieldTapRegion(
              onTapOutside: (_) => _popover.hide(),
              child: ExcludeFocus(
                child: Material(
                  elevation: 8,
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 300,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextEffectGrid(controller: widget.controller, tileHeight: 56, onPicked: _popover.hide),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: widget.builder(_popover.toggle),
      ),
    );
  }
}
