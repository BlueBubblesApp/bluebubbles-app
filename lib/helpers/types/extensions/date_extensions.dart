extension DateHelpers on DateTime {
  bool isTomorrow({DateTime? otherDate}) {
    final now = otherDate?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 1));
    return now.day == day && now.month == month && now.year == year;
  }

  bool isToday() {
    final now = DateTime.now();
    return now.day == day && now.month == month && now.year == year;
  }

  bool isYesterday() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return yesterday.day == day && yesterday.month == month && yesterday.year == year;
  }

  bool isWithin(DateTime other, {int? ms, int? seconds, int? minutes, int? hours, int? days}) {
    Duration diff = difference(other);
    if (ms != null) {
      return diff.inMilliseconds < ms;
    } else if (seconds != null) {
      return diff.inSeconds < seconds;
    } else if (minutes != null) {
      return diff.inMinutes < minutes;
    } else if (hours != null) {
      return diff.inHours < hours;
    } else if (days != null) {
      return diff.inDays < days;
    } else {
      throw Exception("No timerange specified!");
    }
  }
}