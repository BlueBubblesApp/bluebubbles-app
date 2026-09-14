import 'dart:async';

import 'package:bluebubbles/app/layouts/findmy/findmy_handle_matcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';

/// Maintains a single in-memory snapshot of Find My friends (server cache reads
/// only, never Apple) so the conversation-details card can predetermine whether
/// any participant is sharing their location and reserve space on first paint.
///
/// The snapshot is refreshed on stale conversation opens, deduped by a shared
/// in-flight future and bounded by [_ttl].
class FindMyParticipantPrefetch {
  FindMyParticipantPrefetch._();

  static const Duration _ttl = Duration(minutes: 30);
  static const Duration _postCooldown = Duration(seconds: 30);

  static List<FindMyFriend> _snapshot = <FindMyFriend>[];
  static DateTime? _fetchedAt;
  static Future<void>? _inFlight;
  static DateTime? _lastPostAt;

  /// Same capability gate as the Find My nav entry (plus web exclusion), and
  /// off when [Settings.hideFindMyInConversationDetails] is enabled.
  static bool get isSupported =>
      !kIsWeb &&
      SettingsSvc.serverDetails.isMinCatalina &&
      !SettingsSvc.settings.hideFindMyInConversationDetails.value;

  static String controllerTag(String chatGuid) => 'conversation-findmy-location-$chatGuid';

  /// True once a snapshot has been fetched at least once — lets callers
  /// distinguish "nobody is sharing" (known false) from "not loaded yet".
  static bool get hasSnapshot => _fetchedAt != null;

  /// The most recent friends snapshot (may be empty).
  static List<FindMyFriend> get sessionFriends => _snapshot;

  static List<Handle> participantsFor(Chat chat) {
    final state = ChatsSvc.chatStates[chat.guid];
    if (state != null) return state.participants.map((hs) => hs.handle).toList();
    return chat.handles.toList();
  }

  /// Refreshes the snapshot via a server-cache GET (no Apple). Skips when a
  /// fresh snapshot exists (unless [force]) and reuses any in-flight request.
  static Future<void> refreshSnapshot({bool force = false}) {
    if (!isSupported) return Future.value();
    if (_inFlight != null) return _inFlight!;
    if (!force && _fetchedAt != null && DateTime.now().difference(_fetchedAt!) < _ttl) {
      return Future.value();
    }
    _inFlight = _doRefresh().whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  static Future<void> _doRefresh() async {
    try {
      final response = await HttpSvc.icloud.getFriends();
      if (response.statusCode == 200 && response.data['data'] != null) {
        _snapshot = (response.data['data'] as List)
            .map((e) => FindMyFriend.fromJson(e))
            .toList()
            .cast<FindMyFriend>();
        _fetchedAt = DateTime.now();
      }
    } catch (_) {
      // Best-effort server cache read; ignore failures.
    }
  }

  /// Called on conversation open — keeps the snapshot fresh (TTL-gated) so the
  /// details card can answer [hasParticipantSharing] without a round trip.
  static void warm(Chat chat) {
    if (!isSupported) return;
    unawaited(refreshSnapshot());
  }

  /// Whether any participant of [chat] has a friend-with-location in the
  /// current snapshot. Derived on demand — no per-chat caching required.
  static bool hasParticipantSharing(Chat chat) {
    if (_snapshot.isEmpty) return false;
    final sharers =
        _snapshot.where((f) => (f.latitude ?? 0) != 0 && (f.longitude ?? 0) != 0).toList(growable: false);
    if (sharers.isEmpty) return false;
    final participants = participantsFor(chat);
    return sharers.any((f) => FindMyHandleMatcher.matchesAny(f, participants));
  }

  /// Shared cooldown so opening details on several chats within [_postCooldown]
  /// does not trigger repeated Apple refreshes.
  static bool get canPostParticipantRefresh =>
      _lastPostAt == null || DateTime.now().difference(_lastPostAt!) >= _postCooldown;

  static void recordParticipantRefresh() => _lastPostAt = DateTime.now();

  /// Writes an authoritative friends list (from a details live fetch) back into
  /// the snapshot so subsequent sharing checks reflect the freshest data.
  static void updateSnapshot(List<FindMyFriend> friends) {
    _snapshot = List<FindMyFriend>.from(friends);
    _fetchedAt = DateTime.now();
  }

  /// Merges a single friend from a live socket update into the snapshot so
  /// reopening Details hydrates the latest coords instead of a stale GET.
  static void upsertFriend(FindMyFriend friend) {
    final index = _snapshot.indexWhere((e) => FindMyHandleMatcher.friendIdentifiersMatch(e, friend));
    if (index == -1) {
      _snapshot = [..._snapshot, friend];
    } else {
      final next = List<FindMyFriend>.from(_snapshot);
      next[index] = friend;
      _snapshot = next;
    }
    _fetchedAt = DateTime.now();
  }

  static void dispose(String chatGuid) {
    // No per-chat resources are retained; sharing is derived on demand.
  }
}
