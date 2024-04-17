import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Map<String, int> defaultTimeframes = {"1 Hour": 1, "1 Day": 24, "1 Week": 168, "1 Month": 720};

Future<DateTime?> showTimeframePicker(String title, BuildContext context,
    {bool showHourPicker = true,
    bool presetsAhead = false,
    Map<String, int>? customTimeframes,
    Map<String, int>? additionalTimeframes,
    String? selectionSuffix,
    bool useTodayYesterday = false}) async {
  DateTime? finalDate;

  // Sort the selections by the value
  Map<String, int> tfSelections = (customTimeframes ?? defaultTimeframes);
  tfSelections.addAll(additionalTimeframes ?? {});
  tfSelections = Map.fromEntries(tfSelections.entries.toList()..sort((e1, e2) => e1.value.compareTo(e2.value)));

  // Create a list of row widgets where the left side of the row is the "relative" timeframe
  // and the right side is the raw date range
  List<Widget> selections = tfSelections.entries.map((entry) {
    late DateTime tmpDate;

    if (presetsAhead) {
      tmpDate = DateTime.now().toLocal().add(Duration(hours: entry.value));
    } else {
      tmpDate = DateTime.now().toLocal().subtract(Duration(hours: entry.value));
    }

    return InkWell(
        onTap: () {
          finalDate = tmpDate;
          Navigator.of(context).pop();
        },
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            decoration:
                BoxDecoration(border: Border(bottom: BorderSide(color: context.theme.dividerColor.withOpacity(0.2)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${entry.key}${(selectionSuffix != null ? " $selectionSuffix" : "")}",
                    style: context.theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w400)),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                ),
                Text(buildFullDate(tmpDate, includeTime: entry.value < 24, useTodayYesterday: useTodayYesterday),
                    style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.secondary)),
              ],
            )));
  }).toList();

  // Add a custom date picker to the selections list
  selections.add(InkWell(
      onTap: () async {
        finalDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now().toLocal(),
            firstDate: DateTime.now().toLocal().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().toLocal().add(const Duration(days: 365)));

        // If the user selected a date and the time picker is enabled, show the time picker
        if (showHourPicker && finalDate != null) {
          final messageTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
          if (messageTime != null) {
            finalDate =
                DateTime(finalDate!.year, finalDate!.month, finalDate!.day, messageTime.hour, messageTime.minute);
          } else {
            finalDate = null;
          }

          DateTime now = DateTime.now();

          // If the selected date is not in the future, show an error
          if (!presetsAhead && now.isBefore(finalDate!)) {
            showSnackbar("Invalid Date Selection", "Please select a date in the future");
            finalDate = null;
          } else if (presetsAhead && now.isAfter(finalDate!)) {
            showSnackbar("Invalid Date Selection", "Please select a date in the past");
            finalDate = null;
          }

          if (finalDate != null) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Custom Date", style: context.theme.textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w400)),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: context.theme.colorScheme.secondary,
              )
            ],
          ))));

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          title,
          style: context.theme.textTheme.titleLarge,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        content: Scrollbar(
            thumbVisibility: true,
            radius: const Radius.circular(10.0),
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(mainAxisSize: MainAxisSize.min, children: selections)))),
        backgroundColor: context.theme.colorScheme.properSurface,
      );
    },
  );
  return finalDate;
}
