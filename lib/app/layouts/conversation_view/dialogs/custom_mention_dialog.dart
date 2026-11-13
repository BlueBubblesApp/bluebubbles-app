import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

Future<String?> showCustomMentionDialog(BuildContext context, Mentionable? mention, {String? initial}) async {
  final TextEditingController mentionController = TextEditingController(text: initial ?? mention?.displayName);
  String? changed;
  await showBBDialog(
    context: context,
    title: "Custom Mention",
    content: TextField(
      controller: mentionController,
      textCapitalization: TextCapitalization.sentences,
      autocorrect: true,
      scrollPhysics: const CustomBouncingScrollPhysics(),
      autofocus: true,
      enableIMEPersonalizedLearning: !SettingsSvc.settings.incognitoKeyboard.value,
      decoration: InputDecoration(
        labelText: "Custom Mention",
        hintText: mention?.handle.displayName ?? "",
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (val) {
        if (isNullOrEmptyString(val)) {
          val = mention?.handle.displayName ?? "";
        }
        changed = val;
        Navigator.of(context, rootNavigator: true).pop();
      },
    ),
    actions: [
      BBDialogAction(
        text: "Cancel",
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      BBDialogAction(
        text: "OK",
        isDefault: true,
        onPressed: () {
          if (isNullOrEmptyString(mentionController.text)) {
            changed = mention?.handle.displayName ?? "";
          } else {
            changed = mentionController.text;
          }
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    ],
  );
  return changed;
}
