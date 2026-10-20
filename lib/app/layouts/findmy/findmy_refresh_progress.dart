import 'package:bluebubbles/database/models.dart';

/// Identifies a friend within a refresh session. Roster entries and socket
/// events may or may not hydrate a local [Handle], so this keys on the provider
/// address both forms share rather than the service-qualified handle key.
String? findMyFriendRefreshId({required String? rawHandleAddress, required String? hydratedHandleAddress}) {
  String? usable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  return usable(rawHandleAddress) ?? usable(hydratedHandleAddress);
}

String? findMyFriendRefreshIdFor(FindMyFriend friend) =>
    findMyFriendRefreshId(rawHandleAddress: friend.handleAddress, hydratedHandleAddress: friend.handle?.address);

class FindMyRefreshProgress {
  const FindMyRefreshProgress._({required this.active, required this.expectedIds, required this.observedIds});

  factory FindMyRefreshProgress.idle() =>
      const FindMyRefreshProgress._(active: false, expectedIds: {}, observedIds: {});

  factory FindMyRefreshProgress.start() =>
      const FindMyRefreshProgress._(active: true, expectedIds: {}, observedIds: {});

  final bool active;
  final Set<String> expectedIds;
  final Set<String> observedIds;

  int get updated => expectedIds.intersection(observedIds).length;
  int get total => expectedIds.length;
  int get pending => total - updated;

  FindMyRefreshProgress withRoster(Iterable<String?> ids) => FindMyRefreshProgress._(
    active: active,
    expectedIds: Set.unmodifiable(ids.map(_usableId).whereType<String>()),
    observedIds: observedIds,
  );

  FindMyRefreshProgress withUsableEvent(String? id) {
    if (!active) return this;
    final usableId = _usableId(id);
    if (usableId == null) return this;
    return FindMyRefreshProgress._(
      active: active,
      expectedIds: expectedIds,
      observedIds: Set.unmodifiable({...observedIds, usableId}),
    );
  }

  FindMyRefreshProgress finish() =>
      FindMyRefreshProgress._(active: false, expectedIds: expectedIds, observedIds: observedIds);

  bool wasUpdated(String? id) {
    final usableId = _usableId(id);
    return usableId != null && expectedIds.contains(usableId) && observedIds.contains(usableId);
  }

  static String? _usableId(String? id) {
    final trimmed = id?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

enum FindMyFriendRefreshState { updated, locating, lastKnownWaiting, unavailable }

FindMyFriendRefreshState findMyFriendRefreshState(
  FindMyRefreshProgress progress, {
  required String? stableId,
  required bool locatingInProgress,
  required bool hasUsableLocation,
}) {
  if (progress.wasUpdated(stableId)) return FindMyFriendRefreshState.updated;
  if (locatingInProgress) return FindMyFriendRefreshState.locating;
  if (hasUsableLocation) return FindMyFriendRefreshState.lastKnownWaiting;
  return FindMyFriendRefreshState.unavailable;
}

String findMyUpdatingLabel(FindMyRefreshProgress progress) =>
    progress.total == 0 ? "Updating locations…" : "Updating locations · ${progress.updated} of ${progress.total}";
