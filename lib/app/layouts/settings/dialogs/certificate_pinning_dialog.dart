import 'dart:convert';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<bool> showCertificateShaPinningDialog(BuildContext context) async {
  List<TextEditingController> hashControllers = [];
  List<TextEditingController> labelControllers = [];

  // Populate controllers with existing certificates
  if (ss.settings.pinnedCertificateSHAs.isNotEmpty) {
    ss.settings.pinnedCertificateSHAs.forEach((label, hash) {
      labelControllers.add(TextEditingController(text: label));
      hashControllers.add(TextEditingController(text: hash));
    });
  } else {
    // Add one empty row if no certificates exist
    labelControllers.add(TextEditingController());
    hashControllers.add(TextEditingController());
  }

  // Set initial count based on actual controllers
  RxInt certificates = labelControllers.length.obs;

  return await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Certificate Public Key Pinning", style: context.theme.textTheme.titleLarge),
      backgroundColor: context.theme.colorScheme.properSurface,
      content: SingleChildScrollView(
        child: Container(
          width: double.maxFinite,
          child: StatefulBuilder(builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Add SHA256 hashes of your server's public key. This helps ensure secure connections to your server.",
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: context.mediaQuery.size.height * 0.3,
                  ),
                  child: Obx(() {
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: certificates.value,
                      findChildIndexCallback: (key) => findChildIndexByKey(
                        ss.settings.pinnedCertificateSHAs.keys.toList(),
                        key,
                        (item) => item
                      ),
                      itemBuilder: (context, index) {
                        return Column(
                          key: ValueKey(index),
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: TextField(
                                      controller: labelControllers[index],
                                      decoration: const InputDecoration(
                                        labelText: "Label",
                                        hintText: "e.g., Primary, Backup",
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    labelControllers.removeAt(index);
                                    hashControllers.removeAt(index);
                                    setState(() {
                                      certificates.value -= 1;
                                    });
                                  },
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                              child: TextField(
                                controller: hashControllers[index],
                                maxLines: 2,
                                minLines: 1,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                                decoration: const InputDecoration(
                                  labelText: "SHA-256 Hash",
                                  hintText: "Base64 encoded SHA-256 certificate hash",
                                  border: OutlineInputBorder(),
                                  helperText: "44 characters, base64 encoded",
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  }),
                ),
                const SizedBox(height: 5),
                ElevatedButton.icon(
                  onPressed: () {
                    labelControllers.add(TextEditingController());
                    hashControllers.add(TextEditingController());
                    setState(() {
                      certificates.value += 1;
                    });
                  },
                  icon: const Icon(
                    Icons.add,
                    size: 24.0,
                  ),
                  label: const Text('Add Certificate'),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: context.theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'How to get certificate hash:',
                            style: context.theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'To generate the hash of your public key run the following:\n'
                        'openssl x509 -in server.pem -outform DER | openssl dgst -sha256 -binary | base64',
                        style: context.theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          child: Text(
            "Cancel",
            style: context.theme.textTheme.bodyLarge!.copyWith(
              color: context.theme.colorScheme.primary,
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        TextButton(
          child: Text(
            "OK",
            style: context.theme.textTheme.bodyLarge!.copyWith(
              color: context.theme.colorScheme.primary,
            ),
          ),
          onPressed: () async {
            final map = <String, String>{};
            labelControllers.forEachIndexed((index, element) {
              final labelController = element;
              final hashController = hashControllers[index];

              // Validate hash format
              final hash = hashController.text.trim();
              if (labelController.text.isNotEmpty && hash.isNotEmpty) {
                map.addEntries([MapEntry(labelController.text, hash)]);
              }
            });

            ss.settings.pinnedCertificateSHAs.value = map;
            await ss.settings.saveOne('pinnedCertificateSHAs');
            await ss.prefs.setString('pinnedCertificateSHAs', jsonEncode(map));
            // Reinitialize HTTP client with new certificate pins
            http.onInit();
            Navigator.of(context).pop(true);
          },
        ),
      ],
    ),
  ) ?? false;
}
