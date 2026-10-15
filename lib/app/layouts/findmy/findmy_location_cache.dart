import 'dart:convert';

import 'package:bluebubbles/app/layouts/findmy/findmy_friend_sort.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

/// A location Find My reported earlier, kept for when Apple later has no fix.
class FindMyCachedLocation {
  const FindMyCachedLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.label,
    this.fullAddress,
  });

  final double latitude;
  final double longitude;

  /// When Apple located it, in milliseconds since epoch.
  final int timestamp;
  final String? label;
  final String? fullAddress;

  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(timestamp);

  static FindMyCachedLocation? fromJson(Map<String, dynamic> json) {
    final latitude = (json['lat'] as num?)?.toDouble();
    final longitude = (json['lon'] as num?)?.toDouble();
    final timestamp = (json['ts'] as num?)?.toInt();
    if (timestamp == null || !isUsableFindMyCoordinate(latitude, longitude)) return null;
    return FindMyCachedLocation(
      latitude: latitude!,
      longitude: longitude!,
      timestamp: timestamp,
      label: json['label'] as String?,
      fullAddress: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'ts': timestamp,
    if (label != null) 'label': label,
    if (fullAddress != null) 'address': fullAddress,
  };
}

/// Returns [friend] showing [cached] in place of its missing location.
FindMyFriend friendWithCachedLocation(FindMyFriend friend, FindMyCachedLocation cached) => FindMyFriend(
  latitude: cached.latitude,
  longitude: cached.longitude,
  longAddress: cached.fullAddress,
  shortAddress: cached.label,
  title: friend.title,
  subtitle: friend.subtitle,
  handle: friend.handle,
  handleAddress: friend.handleAddress,
  lastUpdated: cached.updatedAt,
  status: null,
  locatingInProgress: false,
  favoriteOrder: friend.favoriteOrder,
);

/// Points [device] at [cached] in place of its missing location.
void applyCachedDeviceLocation(FindMyDevice device, FindMyCachedLocation cached) {
  device.location = Location(
    positionType: null,
    verticalAccuracy: null,
    longitude: cached.longitude,
    floorLevel: null,
    isInaccurate: null,
    isOld: true,
    horizontalAccuracy: null,
    latitude: cached.latitude,
    timeStamp: cached.timestamp,
    altitude: null,
    locationFinished: true,
  );
  device.address = Address(
    subAdministrativeArea: null,
    label: cached.label,
    streetAddress: null,
    countryCode: null,
    stateCode: null,
    administrativeArea: null,
    streetName: null,
    formattedAddressLines: const [],
    mapItemFullAddress: cached.fullAddress,
    fullThroroughfare: null,
    areaOfInterest: const [],
    locality: null,
    country: null,
  );
  device.lastKnownLocationAt = cached.updatedAt;
}

/// Last known location per friend and per logical device or item.
///
/// Holds one account at a time: the cache is tied to the server and iCloud
/// account it was filled from, and starts empty when either changes so one
/// account's locations never show up under another.
class FindMyLocationCache {
  FindMyLocationCache(this.server, this.account, [Map<String, FindMyCachedLocation>? entries])
    : _entries = entries ?? {};

  final String server;
  final String account;
  final Map<String, FindMyCachedLocation> _entries;
  bool _dirty = false;

  static FindMyLocationCache load() {
    final server = SettingsSvc.settings.serverAddress.value;
    final account = SettingsSvc.settings.iCloudAccount.value;
    try {
      final raw = PrefsSvc.findMy.getLocationCache();
      if (raw == null) return FindMyLocationCache(server, account);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedAccount = json['account'] as String? ?? '';
      // The iCloud account is only known once server details have loaded, so an
      // empty value on either side means "unknown", not "different account".
      final sameAccount = savedAccount.isEmpty || account.isEmpty || savedAccount == account;
      if (json['server'] != server || !sameAccount) return FindMyLocationCache(server, account);
      final entries = <String, FindMyCachedLocation>{};
      for (final entry in (json['entries'] as Map<String, dynamic>).entries) {
        final location = FindMyCachedLocation.fromJson(entry.value as Map<String, dynamic>);
        if (location != null) entries[entry.key] = location;
      }
      return FindMyLocationCache(server, account.isNotEmpty ? account : savedAccount, entries);
    } catch (e, s) {
      Logger.warn("Failed to read the Find My location cache", error: e, trace: s, tag: 'FindMyLocationCache');
      return FindMyLocationCache(server, account);
    }
  }

  FindMyCachedLocation? operator [](String key) => _entries[key];

  /// Stores [location] unless the cache already holds a newer fix for [key].
  void remember(String key, FindMyCachedLocation location) {
    final existing = _entries[key];
    if (existing != null && existing.timestamp > location.timestamp) return;
    _entries[key] = location;
    _dirty = true;
  }

  Future<void> save() async {
    if (!_dirty) return;
    _dirty = false;
    await PrefsSvc.findMy.setLocationCache(
      jsonEncode({
        'server': server,
        'account': account,
        'entries': _entries.map((key, value) => MapEntry(key, value.toJson())),
      }),
    );
  }
}
