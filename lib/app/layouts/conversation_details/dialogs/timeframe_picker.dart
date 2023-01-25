import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<DateTime?> showTimeframePicker(String title, BuildContext context, {bool showHourPicker = true, bool presetsAhead = false}) async {
  DateTime? finalDate;
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          title,
          style: context.theme.textTheme.titleLarge,
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("1 Hour", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                onPressed: () {
                  if (presetsAhead) {
                    finalDate = DateTime.now().toLocal().add(const Duration(hours: 1));
                  } else {
                    finalDate = DateTime.now().toLocal().subtract(const Duration(hours: 1));
                  }
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("1 Day", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                onPressed: () {
                  if (presetsAhead) {
                    finalDate = DateTime.now().toLocal().add(const Duration(days: 1));
                  } else {
                    finalDate = DateTime.now().toLocal().subtract(const Duration(days: 1));
                  }
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("1 Week", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                onPressed: () {
                  if (presetsAhead) {
                    finalDate = DateTime.now().toLocal().add(const Duration(days: 7));
                  } else {
                    finalDate = DateTime.now().toLocal().subtract(const Duration(days: 7));
                  }
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("1 Month", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                onPressed: () {
                  if (presetsAhead) {
                    finalDate = DateTime.now().toLocal().add(const Duration(days: 30));
                  } else {
                    finalDate = DateTime.now().toLocal().subtract(const Duration(days: 30));
                  }
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("Custom", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                onPressed: () async {
                  finalDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().toLocal(),
                      firstDate: DateTime.now().toLocal().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().toLocal().add(const Duration(days: 365)));
                  if (showHourPicker && finalDate != null) {
                    final messageTime =
                    await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (messageTime != null) {
                      finalDate = DateTime(finalDate!.year, finalDate!.month, finalDate!.day, messageTime.hour, messageTime.minute);
                    }
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          )
        ]),
        backgroundColor: context.theme.colorScheme.properSurface,
      );
    },
  );
  return finalDate;
}