import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Prompts the user for an API key. Returns the trimmed string on save,
/// an empty string on clear, or `null` if dismissed without saving.
Future<String?> showApiKeyDialog(
  BuildContext context, {
  required String title,
  required String currentValue,
  String? helperText,
  Uri? signupUrl,
}) async {
  final controller = TextEditingController(text: currentValue);
  final obscure = true.obs;
  return await showDialog<String?>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: context.theme.textTheme.titleLarge),
      backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (helperText != null) ...[
              Text(helperText, style: context.theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            Obx(() => TextField(
                  controller: controller,
                  obscureText: obscure.value,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: InputDecoration(
                    labelText: "API Key",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscure.value ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => obscure.value = !obscure.value,
                    ),
                  ),
                )),
            if (signupUrl != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text("Get a key"),
                onPressed: () => launchUrl(signupUrl),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (currentValue.isNotEmpty)
          TextButton(
            child: Text("Clear", style: TextStyle(color: context.theme.colorScheme.error)),
            onPressed: () => Navigator.of(context).pop(""),
          ),
        TextButton(
          child: Text("Cancel", style: context.theme.textTheme.bodyLarge),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        TextButton(
          child: Text("Save", style: context.theme.textTheme.bodyLarge),
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
        ),
      ],
    ),
  );
}
