import 'package:intl/intl.dart';

// Text formats for Find My rows, matching Apple's Find My app.

const double _metersPerMile = 1609.344;

/// Regions that measure road distance in miles.
bool findMyUsesMiles(String? countryCode) => const {'US', 'GB', 'LR', 'MM'}.contains(countryCode?.toUpperCase());

/// "Nearby" when close, one decimal under ten units, whole units after.
String formatFindMyDistance(double meters, {required bool useMiles}) {
  final value = useMiles ? meters / _metersPerMile : meters / 1000;
  final unit = useMiles ? 'mi' : 'km';
  if (value < 0.1) return 'Nearby';
  if (value < 10) return '${value.toStringAsFixed(1)} $unit';
  return '${NumberFormat.decimalPattern('en_US').format(value.round())} $unit';
}

/// How long ago a location was found: "Now", "3 min. ago", "5 hr. ago",
/// "Yesterday", then the date.
String formatFindMyAge(DateTime timestamp, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final age = current.difference(timestamp);
  if (age.inMinutes < 1) return 'Now';
  if (age.inHours < 1) return '${age.inMinutes} min. ago';
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
  if (day == today) return '${age.inHours} hr. ago';
  if (today.difference(day).inDays == 1) return 'Yesterday';
  return DateFormat('M/d/yy').format(timestamp);
}

String joinFindMyParts(Iterable<String?> parts) =>
    parts.whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');
