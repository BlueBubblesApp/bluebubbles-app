import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_actions.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/desktop_attachment_menu.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/buttons/text_field_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/buttons/text_field_button_drag.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/conversation_text_field_local_controller.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:file_picker/file_picker.dart' as pf;
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Left-side icon buttons in the conversation text field row.
///
/// Which buttons appear, and in what order, comes from `SettingsSvc.settings.textFieldButtons`. On desktop the user
/// arranges them here: hold a button to drag it before another, into the slot after the last one to put it last, or
/// onto `+` to move it into the menu. The row makes room where a drop would land ([TextFieldButtonDrag]).
///
/// All button logic is self-contained here; heavy async flows reference
/// [controller] and [localController] directly.
class TextFieldIconBar extends StatelessWidget {
  const TextFieldIconBar({
    super.key,
    required this.controller,
    required this.localController,
  });

  final ConversationViewController controller;
  final ConversationTextFieldLocalController localController;

  Chat get _chat => controller.chat;

  bool get _showAttachmentPicker => controller.showAttachmentPicker.value;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Read here: DragTarget builders run outside this Obx's tracking
      final buttons = SettingsSvc.settings.textFieldButtons.platformSupportedButtons;
      final dragged = TextFieldButtonDrag.dragged.value;
      final at = TextFieldButtonDrag.rowIndex.value;
      final snapping = TextFieldButtonDrag.snap.value;
      Widget slot(Key key, int i, Widget child) => _RowSlot(
            key: key,
            index: i,
            // An invisible copy of the dragged button, so the room is exactly its size
            room: dragged != null && at == i
                ? IgnorePointer(
                    child: Opacity(
                      opacity: 0,
                      child: KeyedSubtree(key: TextFieldButtonDrag.rowSlot, child: _button(dragged)),
                    ),
                  )
                : null,
            snapping: snapping,
            child: child,
          );
      return Row(
        mainAxisSize: MainAxisSize.min,
        // Centered: `+` is smaller than the buttons beside it
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // With nothing left for the menu, `+` only shows while a button is dragged, to drop it in. It slides in and out
          // clipped rather than swapped, and always animates: it goes as a drop lands, which snaps the rest
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 6),
            child: ClipRect(
              child: AnimatedAlign(
                duration: TextFieldButtonDrag.slide,
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerRight,
                widthFactor: kIsDesktop &&
                        dragged == null &&
                        TextFieldButton.values.platformSupportedButtons.every(buttons.contains)
                    ? 0
                    : 1,
                child: _attachmentButton(context),
              ),
            ),
          ),
          for (final (i, b) in buttons.indexed)
            kIsDesktop
                ? slot(ValueKey(b), i, _draggableButton(context, b, i, dragging: b == dragged, snapping: snapping))
                : _button(b),
          if (kIsDesktop) slot(const ValueKey('end'), buttons.length, _endSpace()),
        ],
      );
    });
  }

  Widget _attachmentButton(BuildContext context) {
    final hasBackground = ChatsSvc.getChatState(controller.chat.guid)?.hasCustomWallpaper ?? false;
    Widget button(VoidCallback onPressed) => IconButton(
          style: IconButton.styleFrom(
            backgroundColor: hasBackground
                ? context.theme.colorScheme.surfaceContainerHighest
                : context.theme.colorScheme.outline.withValues(alpha: 0.2),
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 36),
            fixedSize: const Size(36, 36),
          ),
          icon: Icon(
            Icons.add,
            color: context.theme.colorScheme.outline,
            size: 22,
          ),
          visualDensity: Platform.isAndroid ? VisualDensity.compact : null,
          onPressed: onPressed,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: kIsDesktop
          // Desktop has no attachment sheet: `+` opens a menu of the same actions instead. It also takes row
          // buttons dragged onto it
          ? DesktopAttachmentMenu(
              controller: controller,
              inRow: SettingsSvc.settings.textFieldButtons,
              arrangeable: true,
              builder: (_, toggle) => button(toggle),
            )
          : button(() {
              if (kIsWeb) {
                showBBDialog(
                  context: context,
                  title: "What would you like to do?",
                  content: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ListTile(
                        title: Text("Upload file", style: Theme.of(context).textTheme.bodyLarge),
                        onTap: () async {
                          final res = await FilePicker.pickFiles();
                          for (pf.PlatformFile e in res) {
                            final size = await e.length() ?? 0;
                            if (size / 1024000 > 1000) {
                              showSnackbar("Error", "This file is over 1 GB! Please compress it before sending.",
                                  type: SnackbarType.error);
                              continue;
                            }
                            controller.pickedAttachments.add(PlatformFile(
                              path: null,
                              name: e.name,
                              size: size,
                              bytes: await e.readAsBytes(),
                            ));
                          }
                          Get.back();
                        },
                      ),
                      ListTile(
                        title: Text("Send location", style: Theme.of(context).textTheme.bodyLarge),
                        onTap: () async {
                          Share.location(_chat);
                          Get.back();
                        },
                      ),
                    ],
                  ),
                );
              } else {
                if (!_showAttachmentPicker) {
                  controller.focusNode.unfocus();
                  controller.subjectFocusNode.unfocus();
                }
                controller.showAttachmentPicker.value = !_showAttachmentPicker;
              }
            }),
    );
  }

  Widget _button(TextFieldButton b) => Builder(
        // Own context so the Genmoji popover anchors on this button
        builder: (context) => IconButton(
          tooltip: b.label,
          icon: Icon(b.icon, color: context.theme.colorScheme.outline, size: 28),
          onPressed: () => AttachmentActions.run(b, context, controller),
        ),
      );

  /// Room to drop a button at the end of the row: narrow, and as tall as the buttons (an invisible, clipped one), so it
  /// doesn't change the row's height
  Widget _endSpace() => SizedBox(
        width: 16,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            fit: OverflowBoxFit.deferToChild,
            child: IgnorePointer(child: Opacity(opacity: 0, child: _button(TextFieldButton.values.first))),
          ),
        ),
      );

  /// Desktop: hold to drag. While it's dragged its place closes; the room made where it would land shows instead.
  Widget _draggableButton(BuildContext context, TextFieldButton b, int index,
          {required bool dragging, required bool snapping}) =>
      TextFieldButtonDrag.slides(
        snapping: snapping,
        dragging
            ? const SizedBox.shrink()
            : LongPressDraggable<TextFieldButton>(
                data: b,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: centeredDragFeedback(Icon(b.icon, color: context.theme.colorScheme.outline, size: 28)),
                onDragStarted: () => TextFieldButtonDrag.start(b, from: index),
                // These run even though closing its place unmounts this
                onDraggableCanceled: (_, offset) => TextFieldButtonDrag.cancel(context, offset),
                child: _button(b),
              ),
      );
}

/// Desktop: a drop target for the composer row, before the button at [index] (or at the end). It opens room for the
/// dragged button ([room]) when a drop here would put it there.
class _RowSlot extends StatelessWidget {
  const _RowSlot({
    super.key,
    required this.index,
    required this.room,
    required this.snapping,
    required this.child,
  });

  final int index;
  final Widget? room;
  final bool snapping;
  final Widget child;

  @override
  Widget build(BuildContext context) => DragTarget<TextFieldButton>(
        onWillAcceptWithDetails: (_) {
          TextFieldButtonDrag.enterRow(index);
          return true;
        },
        onLeave: (_) => TextFieldButtonDrag.leaveRow(index),
        onAcceptWithDetails: (details) => TextFieldButtonDrag.dropOnRow(context, index, details.offset),
        builder: (context, _, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFieldButtonDrag.slides(room ?? const SizedBox.shrink(), snapping: snapping),
            child,
          ],
        ),
      );
}
