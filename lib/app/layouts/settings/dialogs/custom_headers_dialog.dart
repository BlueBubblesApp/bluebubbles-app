import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<bool> showCustomHeadersDialog(BuildContext context) async {
  int headers = ss.settings.customHeaders.length.clamp(1, 100);
  List<TextEditingController> keyControllers = [];
  List<TextEditingController> valueControllers = [];
  if (ss.settings.customHeaders.isNotEmpty) {
    ss.settings.customHeaders.forEach((key, value) {
      keyControllers.add(TextEditingController(text: key));
      valueControllers.add(TextEditingController(text: value));
    });
  } else {
    keyControllers.add(TextEditingController());
    valueControllers.add(TextEditingController());
  }
  return await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Custom Headers", style: context.theme.textTheme.titleLarge),
      backgroundColor: context.theme.colorScheme.properSurface,
      content: SingleChildScrollView(
        child: Container(
          width: double.maxFinite,
          child: StatefulBuilder(builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: context.mediaQuery.size.height * 0.2,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: headers,
                    findChildIndexCallback: (key) {
                      final valueKey = key as ValueKey<String>;
                      final index = ss.settings.customHeaders.keys.toList().indexWhere((element) => element == valueKey.value);
                      return index == -1 ? null : index;
                    },
                    itemBuilder: (context, index) {
                      return Row(
                          key: ValueKey(ss.settings.customHeaders.keys.toList()[index]),
                          children: [
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextField(
                                  controller: keyControllers[index],
                                  decoration: const InputDecoration(
                                    labelText: "Key",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ),
                            Flexible(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextField(
                                  controller: valueControllers[index],
                                  decoration: const InputDecoration(
                                    labelText: "Value",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ),
                          ]
                      );
                    },
                  ),
                ),
                const SizedBox(height: 5),
                ElevatedButton.icon(
                  onPressed: () {
                    keyControllers.add(TextEditingController());
                    valueControllers.add(TextEditingController());
                    setState(() {
                      headers++;
                    });
                  },
                  icon: const Icon(
                    Icons.add,
                    size: 24.0,
                  ),
                  label: const Text('Add Header'), // <-- Text
                ),
              ],
            );
          }),
        ),
      ),
      actions: [
        TextButton(
            child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () {
              Navigator.of(context).pop(false);
            }
        ),
        TextButton(
            child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () {
              final map = <String, String>{};
              keyControllers.forEachIndexed((index, element) {
                final keyController = element;
                final valueController = valueControllers[index];
                if (keyController.text.isNotEmpty && valueController.text.isNotEmpty) {
                  map.addEntries([MapEntry(keyController.text, valueController.text)]);
                }
              });
              ss.settings.customHeaders.value = map;
              ss.settings.save();
              http.onInit();
              Navigator.of(context).pop(true);
            }
        ),
      ],
    ),
  ) ?? false;
}