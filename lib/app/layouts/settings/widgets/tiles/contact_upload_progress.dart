import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Optimized reactive widget for contact upload progress
/// Only rebuilds when progress, totalSize, or uploadingContacts changes
class ContactUploadProgress extends StatelessWidget {
  final RxnDouble progress;
  final RxnInt totalSize;
  final RxBool uploadingContacts;
  final VoidCallback onClose;

  const ContactUploadProgress({
    super.key,
    required this.progress,
    required this.totalSize,
    required this.uploadingContacts,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
      title: Text("Uploading contacts...", style: context.theme.textTheme.titleLarge),
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Without a size there is nothing to count: the bar alone shows the upload is running.
          Obx(
            () => totalSize.value == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      '${progress.value != null ? (progress.value! * totalSize.value! / 1000).getFriendlySize(withSuffix: false) : ""} / ${(totalSize.value!.toDouble() / 1000).getFriendlySize()} (${((progress.value ?? 0) * 100).floor()}%)',
                      style: context.theme.textTheme.bodyLarge,
                    ),
                  ),
          ),
          Obx(
            () => LinearProgressIndicator(
              backgroundColor: context.theme.colorScheme.outline,
              value: progress.value,
              minHeight: 5,
              valueColor: AlwaysStoppedAnimation<Color>(
                context.theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 15.0),
          Obx(
            () => Text(
              progress.value == 1
                  ? "Upload Complete!"
                  : "You can close this dialog. Contacts will continue to upload in the background.",
              textAlign: TextAlign.center,
              style: context.theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
      actions: [
        Obx(
          () => uploadingContacts.value
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: onClose,
                  child: Text(
                    "Close",
                    style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
                  ),
                ),
        ),
      ],
    );
  }
}
