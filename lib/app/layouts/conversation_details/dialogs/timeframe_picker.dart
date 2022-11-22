import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

Future<Tuple2<int, int>> showTimeframePicker(BuildContext context) async {
  int hours = 0;
  int days = 0;
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          "Select timeframe",
          style: context.theme.textTheme.titleLarge,
        ),
        backgroundColor: context.theme.colorScheme.properSurface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(15),
              child: Text("Note: Longer timeframes may take a while to generate the file", style: context.theme.textTheme.bodyLarge)
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text("1 Hour", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                  onPressed: () {
                    hours = 1;
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text("1 Day", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                  onPressed: () {
                    days = 1;
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text("1 Week", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                  onPressed: () {
                    days = 7;
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text("1 Month", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                  onPressed: () {
                    days = 30;
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text("1 Year", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                  onPressed: () {
                    days = 365;
                    Navigator.of(context).pop();
                  },
                ),
              ],
            )
          ]
        ),
      );
    },
  );
  return Tuple2(days, hours);
}