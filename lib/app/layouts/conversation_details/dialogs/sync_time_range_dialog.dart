import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';

/// A single option in the [showSyncTimeRangeDialog] time-range picker.
class SyncTimeRangeOption {
  const SyncTimeRangeOption({required this.label, required this.duration});

  /// Display label shown to the user (e.g. "1 Week").
  final String label;

  /// How far back from *now* the range extends.
  final Duration duration;
}

/// Default options shown by [showSyncTimeRangeDialog].
const List<SyncTimeRangeOption> defaultSyncTimeRangeOptions = [
  SyncTimeRangeOption(label: "1 Hour", duration: Duration(hours: 1)),
  SyncTimeRangeOption(label: "1 Day", duration: Duration(days: 1)),
  SyncTimeRangeOption(label: "1 Week", duration: Duration(days: 7)),
  SyncTimeRangeOption(label: "1 Month", duration: Duration(days: 30)),
  SyncTimeRangeOption(label: "6 Months", duration: Duration(days: 182)),
  SyncTimeRangeOption(label: "1 Year", duration: Duration(days: 365)),
];

/// Shows a dialog for selecting a time range to sync messages.
///
/// Returns the selected [DateTimeRange] with [DateTimeRange.start] set to
/// `now - option.duration` and [DateTimeRange.end] set to `now`, or `null`
/// if the user dismisses the dialog.
///
/// Pass [options] to replace the default list entirely.
Future<DateTimeRange?> showSyncTimeRangeDialog(
  BuildContext context, {
  List<SyncTimeRangeOption>? options,
}) {
  final effectiveOptions = options ?? defaultSyncTimeRangeOptions;
  final now = DateTime.now().toUtc();

  return showBBListSelector<DateTimeRange>(
    context: context,
    title: "How far back?",
    options: effectiveOptions
        .map((option) => BBListSelectorOption(
              label: option.label,
              value: DateTimeRange(start: now.subtract(option.duration), end: now),
            ))
        .toList(),
  );
}
