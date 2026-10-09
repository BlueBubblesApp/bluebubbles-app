import 'dart:async';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showChangeName(Chat chat, String method, BuildContext context) {
  final controller = TextEditingController(text: chat.displayName);
  final node = FocusNode();
  showBBDialog(
    context: context,
    title: "Change Name",
    content: TextField(
      controller: controller,
      focusNode: node,
      decoration: const InputDecoration(
        labelText: "Chat Name",
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      BBDialogAction(
        text: "OK",
        isDefault: true,
        onPressed: () async {
          node.unfocus();
          if (method == "private-api") {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                    title: Text(
                      controller.text.isEmpty ? "Removing name..." : "Changing name to ${controller.text}...",
                      style: context.theme.textTheme.titleLarge,
                    ),
                    content: SizedBox(
                      height: 70,
                      child: Center(
                        child: CircularProgressIndicator(
                          backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                        ),
                      ),
                    ),
                  );
                });
            final response = await HttpSvc.chat.setDisplayName(chat.guid, controller.text);
            if (response.statusCode == 200) {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context, rootNavigator: true).pop();
              unawaited(ChatsSvc.setChatDisplayName(chat, controller.text));
            } else {
              Navigator.of(context, rootNavigator: true).pop();
              showSnackbar("Error", "Failed to update name!", type: SnackbarType.error);
            }
          } else {
            Navigator.of(context, rootNavigator: true).pop();
            unawaited(ChatsSvc.setChatDisplayName(chat, controller.text));
          }
        },
      ),
      BBDialogAction(
        text: "Cancel",
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    ],
  );
}
