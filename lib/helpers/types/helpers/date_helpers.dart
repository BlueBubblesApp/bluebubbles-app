import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:intl/intl.dart';

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  if (value is DateTime) return value;
  return null;
}

String buildDate(DateTime? dateTime) {
  if (dateTime == null || dateTime.millisecondsSinceEpoch == 0) return "";
  String time = ss.settings.use24HrFormat.value ? DateFormat.Hm().format(dateTime) : DateFormat.jm().format(dateTime);
  String date;
  if (ss.settings.skin.value != Skins.iOS && DateTime.now().difference(dateTime.toLocal()).inMinutes < 1) {
    date = "Just Now";
  } else if (ss.settings.skin.value != Skins.iOS && DateTime.now().difference(dateTime.toLocal()).inHours < 1) {
    date = "${DateTime.now().difference(dateTime.toLocal()).inMinutes} min";
  } else if (dateTime.isToday()) {
    date = time;
  } else if (ss.settings.skin.value == Skins.iOS && dateTime.isYesterday()) {
    date = "Yesterday";
  } else if (DateTime.now().difference(dateTime.toLocal()).inDays <= 7) {
    date = "${DateFormat(ss.settings.skin.value != Skins.iOS ? "EEE" : "EEEE").format(dateTime)}${ss.settings.skin.value != Skins.iOS ? " $time" : ""}";
  } else if (ss.settings.skin.value == Skins.Material && DateTime.now().difference(dateTime.toLocal()).inDays <= 365) {
    date = "${DateFormat.MMMd().format(dateTime)}, $time";
  } else if (ss.settings.skin.value == Skins.Samsung && DateTime.now().year == dateTime.toLocal().year) {
    date = DateFormat.MMMd().format(dateTime);
  } else if (ss.settings.skin.value == Skins.Samsung && DateTime.now().year != dateTime.toLocal().year) {
    date = DateFormat.yMMMd().format(dateTime);
  } else {
    date = DateFormat.yMd().format(dateTime);
  }
  return date;
}

String buildChatListDateMaterial(DateTime? dateTime) {
  if (dateTime == null || dateTime.millisecondsSinceEpoch == 0) return "";
  String date;
  if (DateTime.now().difference(dateTime.toLocal()).inMinutes < 1) {
    date = "Just Now";
  } else if (DateTime.now().difference(dateTime.toLocal()).inHours < 1) {
    date = "${DateTime.now().difference(dateTime.toLocal()).inMinutes} min";
  } else if (DateTime.now().difference(dateTime.toLocal()).inDays <= 7) {
    date = DateFormat("EEE").format(dateTime);
  } else if (ss.settings.skin.value == Skins.Material && DateTime.now().difference(dateTime.toLocal()).inDays <= 365) {
    date = DateFormat.MMMd().format(dateTime);
  } else if (ss.settings.skin.value == Skins.Samsung && DateTime.now().year == dateTime.toLocal().year) {
    date = DateFormat.MMMd().format(dateTime);
  } else if (ss.settings.skin.value == Skins.Samsung && DateTime.now().year != dateTime.toLocal().year) {
    date = DateFormat.yMMMd().format(dateTime);
  } else {
    date = DateFormat.yMd().format(dateTime);
  }
  return date;
}

String buildSeparatorDateMaterial(DateTime dateTime) {
  return DateFormat.MMMEd().format(dateTime);
}

String buildSeparatorDateSamsung(DateTime dateTime) {
  return DateFormat.yMMMMEEEEd().format(dateTime);
}

String buildTime(DateTime? dateTime) {
  if (dateTime == null || dateTime.millisecondsSinceEpoch == 0) return "";
  String time = ss.settings.use24HrFormat.value ? DateFormat.Hm().format(dateTime) : DateFormat.jm().format(dateTime);
  return time;
}

String buildFullDate(DateTime time, {bool includeTime = true, bool useTodayYesterday = true}) {
  if (time.millisecondsSinceEpoch == 0) return "";

  late String date;
  if (includeTime) {
    if (ss.settings.use24HrFormat.value) {
      if (useTodayYesterday) {
        if (time.isToday()) {
          date = "Today, ${DateFormat.Hm().format(time)}";
        } else if (time.isYesterday()) {
          date = "Yesterday, ${DateFormat.Hm().format(time)}";
        } else {
          date = DateFormat.yMd().add_Hm().format(time);
        }
      } else {
        date = DateFormat.yMd().add_Hm().format(time);
      }
    } else {
      if (useTodayYesterday) {
        if (time.isToday()) {
          date = "Today, ${DateFormat.jm().format(time)}";
        } else if (time.isYesterday()) {
          date = "Yesterday, ${DateFormat.jm().format(time)}";
        } else {
          date = DateFormat.yMd().add_jm().format(time);
        }
      } else {
        date = DateFormat.yMd().add_jm().format(time);
      }
    }
  } else {
    if (useTodayYesterday) {
      if (time.isToday()) {
        date = "Today";
      } else if (time.isYesterday()) {
        date = "Yesterday";
      } else {
        date = DateFormat.yMd().format(time);
      }
    } else {
      date = DateFormat.yMd().format(time);
    }
  }

  return date;
}
