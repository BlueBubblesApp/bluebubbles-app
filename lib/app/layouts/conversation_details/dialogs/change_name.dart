import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showChangeName(Chat chat, String method, BuildContext context) {
  final controller = TextEditingController(text: chat.displayName);
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        backgroundColor: context.theme.colorScheme.properSurface,
        actions: [
          TextButton(
            child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () async {
              if (method == "private-api") {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: context.theme.colorScheme.properSurface,
                      title: Text(
                        controller.text.isEmpty ? "Removing name..." : "Changing name to ${controller.text}...",
                        style: context.theme.textTheme.titleLarge,
                      ),
                      content: Container(
                        height: 70,
                        child: Center(
                          child: CircularProgressIndicator(
                            backgroundColor: context.theme.colorScheme.properSurface,
                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                          ),
                        ),
                      ),
                    );
                  }
                );
                final response = await http.updateChat(chat.guid, controller.text);
                if (response.statusCode == 200) {
                  Get.back();
                  Get.back();
                  chat.changeName(controller.text);
                  showSnackbar("Notice", "Updated name successfully!");
                } else {
                  Get.back();
                  showSnackbar("Error", "Failed to update name!");
                }
              } else {
                Get.back();
                chat.changeName(controller.text);
              }
            },
          ),
          TextButton(
            child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () => Get.back(),
          ),
        ],
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Chat Name",
            border: OutlineInputBorder(),
          ),
        ),
        title: Text("Change Name", style: context.theme.textTheme.titleLarge),
      );
    }
  );
}