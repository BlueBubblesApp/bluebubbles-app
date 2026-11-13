import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/desktop_attachment_menu.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/buttons/text_field_button.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_acrylic/window_effect.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Desktop only: reorder the buttons to the left of the message text field, and pick which
/// ones go in the `+` menu instead.
class TextFieldButtonsPanel extends StatefulWidget {
  const TextFieldButtonsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _TextFieldButtonsPanelState();
}

class _TextFieldButtonsPanelState extends State<TextFieldButtonsPanel> with ThemeHelpers {
  /// Enabled buttons, in order — the local source of truth for both the preview and
  /// the chips. The ReorderableWrap must never rebuild from the settings list while a
  /// drag is in flight, or it tears down its DragTargets and trips an assert in
  /// drag_target.dart. So: mutate this, then persist.
  final RxList<TextFieldButton> enabled = RxList();

  @override
  void initState() {
    super.initState();
    final saved = SettingsSvc.settings.textFieldButtons.platformSupportedButtons;
    enabled.value = saved;
  }

  /// Button the pointer is currently over, for hover feedback
  TextFieldButton? _hovered;

  /// Hover feedback is suppressed while a drag is in flight — the pointer passes over
  /// every icon on the way to the drop target, which would light them all up
  bool _dragging = false;

  /// Content padding of the real TextFields (text_field_component.dart)
  double get _pad => iOS && !kIsDesktop && !kIsWeb ? 10 : 12.5;

  /// A disabled copy of the real TextField (text_field_component.dart) — same decoration
  /// and style, so the preview's height and padding match exactly instead of being eyeballed
  Widget _fakeField(BuildContext context, String hint, {bool bold = false}) {
    final style = context.theme.extension<BubbleText>()!.bubbleText;
    return TextField(
      enabled: false,
      style: bold ? style.copyWith(fontWeight: FontWeight.bold) : style,
      decoration: InputDecoration(
        contentPadding: EdgeInsets.all(_pad),
        isDense: true,
        isCollapsed: true,
        hintText: hint,
        enabledBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        fillColor: Colors.transparent,
        hintStyle: style.copyWith(
          color: context.theme.colorScheme.outline,
          fontWeight: bold ? FontWeight.bold : null,
        ),
      ),
    );
  }

  /// Paints the settings tile background behind [child]. Used instead of the section's
  /// own background so the preview's band can stay transparent.
  Widget _tiled(Widget child) => ColoredBox(color: tileColor, child: child);

  void _save() => SettingsSvc.settings.setTextFieldButtons(enabled.toList());

  void _endDrag() {
    if (!mounted || !_dragging) return;
    setState(() => _dragging = false);
  }

  /// A draggable button: an icon in the row preview, or an item in the menu preview ([menuItem]).
  Widget _icon(BuildContext context, TextFieldButton b, {bool menuItem = false}) {
    return StatefulBuilder(builder: (context, setLocalState) {
      bool hovered = _hovered == b && !_dragging;
      final icon = MouseRegion(
        cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        onEnter: (_) => setLocalState(() => _hovered = b),
        onExit: (_) => setLocalState(() => _hovered = null),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: menuItem ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 4),
          padding: menuItem ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8) : const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: hovered ? context.theme.colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          ),
          child: menuItem
              ? _menuItem(context, b)
              : Icon(b.icon,
                  color: hovered ? context.theme.colorScheme.primary : context.theme.colorScheme.outline, size: 28),
        ),
      );
      return Draggable<TextFieldButton>(
        data: b,
        onDragStarted: () => setState(() {
          _dragging = true;
          _hovered = null;
        }),
        // onDragEnd doesn't fire if the drop rebuilt this Draggable out of existence,
        // so the drop targets call _endDrag() as well
        onDragEnd: (_) => _endDrag(),
        feedback: Material(
          color: Colors.transparent,
          child: Icon(b.icon, color: context.theme.colorScheme.primary, size: 32),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: icon),
        child: icon,
      );
    });
  }

  /// Mirrors DesktopAttachmentMenu._item
  Widget _menuItem(BuildContext context, TextFieldButton b) {
    final (icon, color) = desktopMenuIcons[b]!;
    return SizedBox(
      width: 196,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 16),
          Text(b.label, style: context.theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  /// Drop slot that moves/inserts the dragged button at [index] of the enabled list.
  Widget _slot(BuildContext context, int index, {required Widget child}) =>
      DragTarget<TextFieldButton>(onAcceptWithDetails: (details) {
        final b = details.data;
        final target = enabled.contains(b) && enabled.indexOf(b) < index ? index - 1 : index;
        enabled.remove(b);
        enabled.insert(target.clamp(0, enabled.length), b);
        _save();
        _endDrag();
      }, builder: (context, candidate, _) {
        // foregroundDecoration paints over the child instead of insetting it, so
        // hovering a drop target doesn't shift the whole row over
        return Container(
          foregroundDecoration: candidate.isEmpty
              ? null
              : BoxDecoration(
                  border: Border(left: BorderSide(color: context.theme.colorScheme.primary, width: 2))),
          child: child,
        );
      });

  /// Mock of the composer row — the real one is [TextFieldIconBar] + the text field,
  /// sitting on the conversation view background ([ColorScheme.surface]).
  Widget _preview(BuildContext context) {
    final showSubject =
        SettingsSvc.settings.enablePrivateAPI.value && SettingsSvc.settings.privateSubjectLine.value;
    return Container(
      // Same as the conversation view scaffold — window effects show through instead
      color: SettingsSvc.settings.windowEffect.value != WindowEffect.disabled
          ? Colors.transparent
          : context.theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (enabled.leavesMenuEmpty)
            const SizedBox(width: 6)
          else
            Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: context.theme.colorScheme.outline.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: context.theme.colorScheme.outline, size: 22),
            ),
          ),
          // Each enabled icon is a drop slot: dropping onto it inserts before it
          ...enabled.mapIndexed((i, b) => _slot(context, i, child: _icon(context, b))),
          // The text field itself is the trailing drop slot, so there's always a big
          // target to drag a hidden button back into the row
          Expanded(
            child: _slot(
              context,
              enabled.length,
              // Mirrors the real field: iOS gets an outline, other skins get a fill, and
              // the subject line adds a second row above the message row
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: iOS ? null : context.theme.colorScheme.surfaceContainerHighest,
                  border: iOS ? Border.all(color: context.theme.colorScheme.outline.withValues(alpha: 0.5)) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showSubject) ...[
                      _fakeField(context, "Subject", bold: true),
                      // Matches text_field_component.dart — iOS only
                      if (iOS)
                        Divider(
                          height: 1.5,
                          thickness: 1.5,
                          indent: 10,
                          color: context.theme.colorScheme.surfaceContainerHighest,
                        ),
                    ],
                    Row(
                      children: [
                        Expanded(child: _fakeField(context, "iMessage")),
                        Padding(
                          padding: EdgeInsets.only(right: _pad),
                          child: Icon(
                            iOS ? CupertinoIcons.mic_fill : Icons.mic_none,
                            color: iOS
                                ? context.theme.colorScheme.outline.withValues(alpha: 0.8)
                                : context.theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Text Field Buttons",
      initialHeader: "Preview",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      headerColor: headerColor,
      tileColor: tileColor,
      actions: [
        TextButton(
          child: Text("Reset",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
          onPressed: () {
            SettingsSvc.settings.resetTextFieldButtons();
            enabled.value = defaultTextFieldButtons.platformSupportedButtons;
          },
        ),
      ],
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            SettingsSection(
              // Transparent so the tile can be painted around the preview instead of
              // behind it — see _tiled() and the rails below
              backgroundColor: Colors.transparent,
              children: [
                _tiled(const SettingsSubtitle(
                  subtitle:
                      "Drag buttons between the composer and the + menu above it to choose where they go, and within the composer to reorder them.",
                )),
                _tiled(Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  // Live + menu: everything not in the row, drawn like DesktopAttachmentMenu
                  child: Obx(() {
                    // Read the observables here — inside DragTarget's builder they run in a
                    // deferred callback that Obx can't see, which trips its "improper use" error
                    final hidden = TextFieldButton.values.platformSupportedButtons.whereNot(enabled.contains).toList();
                    return DragTarget<TextFieldButton>(
                      onAcceptWithDetails: (details) {
                        enabled.remove(details.data);
                        _save();
                        _endDrag();
                      },
                      builder: (context, candidate, _) {
                        final scheme = context.theme.colorScheme;
                        // Full width so the whole band is a drop target, not just the menu
                        return Container(
                          width: double.infinity,
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: candidate.isEmpty ? scheme.outline.withValues(alpha: 0.15) : scheme.primary,
                                width: candidate.isEmpty ? 1 : 2,
                              ),
                            ),
                            child: hidden.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Text("Drag a button here to move it to the + menu",
                                        style: context.theme.textTheme.bodyMedium!.copyWith(color: scheme.outline)),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: hidden.map((b) => _icon(context, b, menuItem: true)).toList(),
                                  ),
                          ),
                        );
                      },
                    );
                  }),
                )),
                // The tile is painted as rails around the preview, leaving its band
                // transparent so window effects show through exactly there
                _tiled(const SizedBox(height: 16, width: double.infinity)),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      _tiled(const SizedBox(width: 16, height: double.infinity)),
                      Expanded(child: Obx(() => _preview(context))),
                      _tiled(const SizedBox(width: 16, height: double.infinity)),
                    ],
                  ),
                ),
                _tiled(const SizedBox(height: 16, width: double.infinity)),
              ],
            ),
          ]),
        ),
      ],
    );
  }
}
