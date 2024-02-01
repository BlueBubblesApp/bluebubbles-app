import 'package:bluebubbles/models/models.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:tuple/tuple.dart';

enum LocationStatus {legacy, shallow, live}

class FindMyFriend {
  FindMyFriend({
    required this.latitude,
    required this.longitude,
    required this.longAddress,
    required this.shortAddress,
    required this.title,
    required this.subtitle,
    required this.handle,
    required this.lastUpdated,
    required this.status,
    required this.locatingInProgress,
  });

  final double? latitude;
  final double? longitude;
  final String? longAddress;
  final String? shortAddress;
  final String? title;
  final String? subtitle;
  final Handle? handle;
  final DateTime? lastUpdated;
  final LocationStatus? status;
  final bool locatingInProgress;

  factory FindMyFriend.fromJson(Map<String, dynamic> json) => FindMyFriend(
    latitude: json["coordinates"]?[0].toDouble(),
    longitude: json["coordinates"]?[1].toDouble(),
    longAddress: json["long_address"],
    shortAddress: json["short_address"],
    title: json["title"],
    subtitle: json["subtitle"],
    handle: json["handle"] == null ? null : Handle.findOne(addressAndService: Tuple2(json["handle"], "iMessage")),
    lastUpdated: (json["last_updated"] ?? 0) == 0 ? null : DateTime.fromMillisecondsSinceEpoch(json["last_updated"]),
    status: LocationStatus.values.firstWhereOrNull((e) => e.name == json["status"]),
    locatingInProgress: json["is_locating_in_progress"] ?? false,
  );

  Map<String, dynamic> toJson() => {
    "coordinates": [latitude, longitude],
    "long_address": longAddress,
    "short_address": shortAddress,
    "title": title,
    "subtitle": subtitle,
    "handle": handle?.toMap(),
    "last_updated": lastUpdated == null ? null : DateFormat("MMMM d, yyyy h:mm:ss a").format(lastUpdated!),
    "status": status?.name,
    "locating_in_progress": locatingInProgress,
  };
}

