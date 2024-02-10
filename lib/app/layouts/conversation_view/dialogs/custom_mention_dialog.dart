import 'package:bluebubbles/app/components/custom/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<String?> showCustomMentionDialog(BuildContext context, Mentionable? mention) async {
  final TextEditingController mentionController = TextEditingController(text: mention?.displayName);
  String? changed;
  await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          actions: [
            TextButton(
              child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () => Get.back(),
            ),
            TextButton(
              child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
              onPressed: () {
                if (isNullOrEmptyString(mentionController.text)) {
                  changed = mention?.handle.displayName ?? "";
                } else {
                  changed = mentionController.text;
                }
                Get.back();
              },
            ),
          ],
          content: TextField(
            controller: mentionController,
            textCapitalization: TextCapitalization.sentences,
            autocorrect: true,
            scrollPhysics: const CustomBouncingScrollPhysics(),
            autofocus: true,
            enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
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
              Get.back();
            },
          ),
          title: Text("Custom Mention", style: context.theme.textTheme.titleLarge),
          backgroundColor: context.theme.colorScheme.properSurface,
        );
      }
  );
  return changed;
}