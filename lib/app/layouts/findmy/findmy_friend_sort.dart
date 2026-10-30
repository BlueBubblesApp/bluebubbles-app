import 'package:bluebubbles/database/models.dart';
import 'package:geolocator/geolocator.dart';

bool isUsableFindMyCoordinate(double? latitude, double? longitude) {
  return latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      (latitude != 0 || longitude != 0);
}

bool hasUsableFindMyLocation(FindMyFriend friend) {
  return isUsableFindMyCoordinate(friend.latitude, friend.longitude);
}

/// Returns friends nearest to [originLatitude], [originLongitude] first.
///
/// The display name and stable ID make equal-distance results deterministic.
List<FindMyFriend> sortFindMyFriendsByDistance(
  Iterable<FindMyFriend> friends, {
  required double originLatitude,
  required double originLongitude,
}) {
  final sorted = friends.toList();
  sorted.sort((a, b) {
    final aDistance = Geolocator.distanceBetween(originLatitude, originLongitude, a.latitude!, a.longitude!);
    final bDistance = Geolocator.distanceBetween(originLatitude, originLongitude, b.latitude!, b.longitude!);
    final distanceComparison = aDistance.compareTo(bDistance);
    if (distanceComparison != 0) return distanceComparison;

    final nameComparison = _sortKey(a).compareTo(_sortKey(b));
    if (nameComparison != 0) return nameComparison;
    return (a.stableId ?? '').compareTo(b.stableId ?? '');
  });
  return sorted;
}

String _sortKey(FindMyFriend friend) => (friend.handle?.displayName ?? friend.title ?? '').toLowerCase();
