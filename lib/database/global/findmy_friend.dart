import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/models/models.dart' show HandleLookupKey;
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

enum LocationStatus { legacy, shallow, live }

class FindMyFriend {
  FindMyFriend({
    required this.latitude,
    required this.longitude,
    required this.longAddress,
    required this.shortAddress,
    required this.title,
    required this.subtitle,
    required this.handle,
    required this.handleAddress,
    required this.lastUpdated,
    required this.status,
    required this.locatingInProgress,
    this.avatar,
  });

  final double? latitude;
  final double? longitude;
  final String? longAddress;
  final String? shortAddress;
  final String? title;
  final String? subtitle;
  final Handle? handle;
  // Raw address from the server — stable even when handle is not in the local DB.
  final String? handleAddress;
  final DateTime? lastUpdated;
  final LocationStatus? status;
  final bool locatingInProgress;
  // Base64-encoded contact photo from the server, when the friend's handle matches
  // a contact with an image on the host. Null when the server has no photo.
  final String? avatar;

  /// Stable identifier for matching and map marker keys.
  /// Prefers the hydrated handle key; falls back to the raw server address.
  String? get stableId => handle?.uniqueAddressAndService ?? handleAddress;

  factory FindMyFriend.fromJson(Map<String, dynamic> json) => FindMyFriend(
        latitude: json["coordinates"]?[0].toDouble(),
        longitude: json["coordinates"]?[1].toDouble(),
        longAddress: json["long_address"],
        shortAddress: json["short_address"],
        title: json["title"],
        subtitle: json["subtitle"],
        handleAddress: json["handle"] ?? json["title"],
        handle: json["handle"] == null && json["title"] == null
            ? null
            : Handle.findOne(addressAndService: HandleLookupKey(json["handle"] ?? json["title"], "iMessage")),
        lastUpdated:
            (json["last_updated"] ?? 0) == 0 ? null : DateTime.fromMillisecondsSinceEpoch(json["last_updated"]),
        status: LocationStatus.values.firstWhereOrNull((e) => e.name == json["status"]),
        locatingInProgress: json["is_locating_in_progress"] ?? false,
        avatar: json["avatar"],
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
        "avatar": avatar,
      };
}
