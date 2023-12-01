import 'package:bluebubbles/models/models.dart';
import 'package:tuple/tuple.dart';

class FindMyFriend {
  FindMyFriend({
    required this.latitude,
    required this.longitude,
    required this.longAddress,
    required this.shortAddress,
    required this.title,
    required this.subtitle,
    required this.handle,
  });

  final double? latitude;
  final double? longitude;
  final String? longAddress;
  final String? shortAddress;
  final String? title;
  final String? subtitle;
  final Handle? handle;

  factory FindMyFriend.fromJson(Map<String, dynamic> json) => FindMyFriend(
    latitude: json["coordinates"]?[0].toDouble(),
    longitude: json["coordinates"]?[1].toDouble(),
    longAddress: json["long_address"],
    shortAddress: json["short_address"],
    title: json["title"],
    subtitle: json["subtitle"],
    handle: json["handle"] == null ? null : Handle.findOne(addressAndService: Tuple2(json["handle"], "iMessage")),
  );

  Map<String, dynamic> toJson() => {
    "coordinates": [latitude, longitude],
    "long_address": longAddress,
    "short_address": shortAddress,
    "title": title,
    "subtitle": subtitle,
    "handle": handle?.address,
  };
}

