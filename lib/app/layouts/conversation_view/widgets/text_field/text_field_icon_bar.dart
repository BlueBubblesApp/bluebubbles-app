import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/attachment_actions.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/media_picker/desktop_attachment_menu.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/buttons/text_field_button.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/conversation_text_field_local_controller.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:file_picker/file_picker.dart' as pf;
import 'package:file_picker/file_picker.dart' hide PlatformFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Left-side icon buttons in the conversation text field row.
///
/// Which buttons appear, and in what order, comes from
/// `SettingsSvc.settings.textFieldButtons` (configurable — see [TextFieldButton]).
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
    return Obx(() => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (kIsDesktop && SettingsSvc.settings.textFieldButtons.leavesMenuEmpty)
              const SizedBox(width: 6)
            else
              _attachmentButton(context),
            ...SettingsSvc.settings.textFieldButtons.platformSupportedButtons.map(_button),
          ],
        ));
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
          // Desktop has no attachment sheet: `+` opens a menu of the same actions instead.
          ? DesktopAttachmentMenu(
              controller: controller,
              inRow: SettingsSvc.settings.textFieldButtons,
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
}
