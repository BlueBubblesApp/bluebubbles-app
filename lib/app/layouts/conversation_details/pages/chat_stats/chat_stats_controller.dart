import 'dart:async';
import 'dart:isolate';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/ui/async_task.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_computer.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_models.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_queries.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:get/get.dart';

/// Caches computed [ChatStats] per chat *and* timeframe, self-invalidating on
/// new messages.
///
/// Keyed on `(sourceMessageCount, sourceLatestMillis)` so a chat gaining or
/// losing messages busts the cache without any event-listener plumbing. The
/// cache key string itself must already fold in the timeframe (the caller
/// composes it, e.g. `'$guid:${timeframe.name}'`) — otherwise switching
/// timeframes and back would return stats computed for the wrong window.
class ChatStatsCache {
  static final _entries = <String, ChatStats>{};

  static ChatStats? get(String cacheKey, ({int count, int latestMillis}) key) {
    final hit = _entries[cacheKey];
    if (hit == null) return null;
    if (hit.sourceMessageCount != key.count || hit.sourceLatestMillis != key.latestMillis) {
      return null;
    }
    return hit;
  }

  static void put(String cacheKey, ChatStats stats) {
    if (_entries.length > 10) _entries.clear(); // crude bound; these are not tiny
    _entries[cacheKey] = stats;
  }
}

/// Orchestrates per-section lazy loading for the Chat Stats page: staged
/// progress, isolate-backed aggregation, participant resolution, and caching.
///
/// See `docs/feature-planning/chat-stats/tasks/06-controller-and-caching.md`.
class ChatStatsController extends GetxController {
  ChatStatsController(this.chat);
  final Chat chat;

  final Rxn<ChatStats> stats = Rxn<ChatStats>();
  final Rx<ChatStatsProgress> progress = ChatStatsProgress.idle.obs;
  final RxnString error = RxnString();
  late final StatsDetailTier tier;

  /// Participant display metadata, resolved once from ContactsSvcV2/HandleSvc.
  final RxMap<int, ParticipantInfo> participants = <int, ParticipantInfo>{}.obs;

  bool get isGroup => chat.isGroup;

  /// Cached raw fetch, shared by every section so the DB is hit once per load
  /// — re-fetched (see [_byParticipantTimeframe]) whenever [timeframe] changes.
  Map<int, List<int>>? _byParticipant;

  /// The [timeframe] value [_byParticipant] was fetched for. When this
  /// doesn't match the current [timeframe], the cached fetch is stale.
  StatsTimeframe? _byParticipantTimeframe;

  /// Page-level window re-scoping every section to a span ending now. Changing
  /// it invalidates the fetch and every already-computed section — see
  /// [setTimeframe].
  final Rx<StatsTimeframe> timeframe = StatsTimeframe.year.obs;

  /// Guards against duplicate concurrent computation of the same section.
  final Set<StatsStage> _inFlight = {};

  /// UI-only view state — changing this must NOT trigger a recompute. Local
  /// to the Activity tab's own bucket-granularity control — distinct from
  /// [timeframe], which is the page-level window and the only windowing
  /// control now (the Activity tab used to have its own; removed as redundant).
  final Rx<StatsBucketSize> bucketSize = StatsBucketSize.day.obs;

  /// `(count, latestMillis)` at last resolution — the cache key. Resolved once
  /// in [init] and reused by every section so a reopen doesn't re-hit the DB
  /// just to check whether the cache is still valid.
  ({int count, int latestMillis})? _cacheKey;

  Future<void> init() async {
    // Cheap size probe decides how the whole page behaves.
    final count = await runAsync(() => ChatStatsQueries.messageCountForTier(chat));
    tier = tierFor(count);
    if (tier == StatsDetailTier.large) {
      bucketSize.value = StatsBucketSize.month; // coarser default
    }

    await _resolveParticipants();

    // The Overview tab's own `initState` already calls `ensureSection` for
    // this stage — calling it again here raced against that call: whichever
    // finished last would overwrite `stats.value` with a `_base()` snapshot
    // taken before the other's write landed, occasionally reverting freshly
    // shown content back to null (a visible flash-then-skeleton). Resolving
    // `_cacheKey` and applying a cache hit both now live inside
    // `ensureSection` itself (idempotently), so there's nothing left for
    // `init()` to do here beyond kicking off the small-tier eager section.

    // Small chats can afford everything up front; larger ones wait for tab visits.
    if (tier == StatsDetailTier.small) {
      unawaited(ensureSection(StatsStage.computingActivity));
    }
  }

  /// Computes [stage] if not already cached or in flight. Each tab calls this
  /// from its `initState` — nothing computes until its tab is actually opened.
  /// Pass `force: true` (from a refresh action) to recompute even if cached.
  Future<void> ensureSection(StatsStage stage, {bool force = false}) async {
    if (_inFlight.contains(stage)) return;
    if (!force && _isComputed(stage)) return;
    _inFlight.add(stage);
    // Tabs call this from `initState`, which runs mid-build — yield to a
    // microtask first so the Rx writes below land after the current build
    // phase finishes, not during it (otherwise Obx.setState fires while the
    // framework is still building this exact subtree).
    await Future<void>.value();
    try {
      error.value = null;
      progress.value = const ChatStatsProgress(StatsStage.loadingMessages);
      // The sole place `_cacheKey` is resolved and a cache hit is applied —
      // `??=` on both makes this safe no matter which caller (a tab's
      // `initState`, or `init()`'s small-tier kickoff) reaches it first, and
      // never clobbers data another in-flight call already produced.
      _cacheKey ??= await runAsync(() => ChatStatsQueries.cacheKey(chat));
      stats.value ??= ChatStatsCache.get(_cacheEntryKey, _cacheKey!);
      final currentTimeframe = timeframe.value;
      if (_byParticipant == null || _byParticipantTimeframe != currentTimeframe) {
        final fetchWatch = Stopwatch()..start();
        _byParticipant = await runAsync(
          () => ChatStatsQueries.timestampsByParticipant(chat, sinceMillis: currentTimeframe.cutoffMillis()),
        );
        _byParticipantTimeframe = currentTimeframe;
        Logger.debug(
          'Fetched timestampsByParticipant for ${chat.guid} (${currentTimeframe.label}, ${_byParticipant!.values.fold<int>(0, (a, b) => a + b.length)} messages) in ${fetchWatch.elapsedMilliseconds}ms',
          tag: 'ChatStats',
        );
      }

      progress.value = ChatStatsProgress(stage);
      final computeWatch = Stopwatch()..start();
      // `_base()` is deliberately read AFTER the `await`, not before — two
      // different stages (e.g. Overview from a tab's `initState`, Activity from
      // the small-tier eager kickoff) can compute concurrently, and reading
      // `_base()` up front would snapshot `stats.value` before the other
      // stage's write landed, so whichever finished last would clobber it on
      // write. Reading it here, immediately before the assignment (with no
      // `await` between the two), means it always reflects the latest write.
      switch (stage) {
        case StatsStage.computingOverview:
          final overview = await _computeOverview();
          stats.value = _base().copyWith(overview: overview);
        case StatsStage.computingActivity:
          final activity = await _computeActivity();
          stats.value = _base().copyWith(activity: activity);
        case StatsStage.computingEngagement:
          final engagement = await _computeEngagement();
          stats.value = _base().copyWith(engagement: engagement);
        case StatsStage.computingContent:
          final content = await _computeContent();
          stats.value = _base().copyWith(content: content);
        default:
          break;
      }
      Logger.debug('Computed $stage for ${chat.guid} in ${computeWatch.elapsedMilliseconds}ms', tag: 'ChatStats');
      ChatStatsCache.put(_cacheEntryKey, stats.value!);
    } catch (e, s) {
      Logger.error('Failed to compute $stage', error: e, trace: s, tag: 'ChatStats');
      error.value = 'Could not load these stats.';
    } finally {
      _inFlight.remove(stage);
      progress.value = ChatStatsProgress.idle;
    }
  }

  bool _isComputed(StatsStage stage) => switch (stage) {
        StatsStage.computingOverview => stats.value?.overview != null,
        StatsStage.computingActivity => stats.value?.activity != null,
        StatsStage.computingEngagement => stats.value?.engagement != null,
        StatsStage.computingContent => stats.value?.content != null,
        _ => false,
      };

  /// The stats object every section's `copyWith` builds on — either what's
  /// already loaded/cached, or a fresh empty shell keyed for this source state.
  ChatStats _base() =>
      stats.value ?? ChatStats(sourceMessageCount: _cacheKey!.count, sourceLatestMillis: _cacheKey!.latestMillis);

  /// [ChatStatsCache] key — folds in [timeframe] so switching windows and
  /// back doesn't return another window's cached stats.
  String get _cacheEntryKey => '${chat.guid}:${timeframe.value.name}';

  Future<OverviewStats> _computeOverview() async {
    final byParticipant = _byParticipant!;
    // Matches the window `_byParticipant` was actually fetched for, not
    // necessarily `timeframe.value` — the two could momentarily diverge if
    // `timeframe` changes again while this section is still computing.
    final sinceMillis = _byParticipantTimeframe!.cutoffMillis();
    final attachments = await runAsync(() => ChatStatsQueries.attachmentMessageCount(chat, sinceMillis: sinceMillis));
    final unattributed = await runAsync(() => ChatStatsQueries.unattributedCount(chat, sinceMillis: sinceMillis));

    return _isolateOverview(
      byParticipant: byParticipant,
      attachments: attachments,
      unattributedCount: unattributed,
    );
  }

  Future<ActivityStats> _computeActivity() async {
    final byParticipant = _byParticipant!;
    return _isolateActivity(byParticipant: byParticipant);
  }

  Future<EngagementStats> _computeEngagement() async {
    final byParticipant = _byParticipant!;
    final group = isGroup;
    final sinceMillis = _byParticipantTimeframe!.cutoffMillis();
    final readMillis =
        group ? <int>[] : await runAsync(() => ChatStatsQueries.readTimestamps(chat, sinceMillis: sinceMillis));
    return _isolateEngagement(
      byParticipant: byParticipant,
      readMillis: readMillis,
      isGroup: group,
    );
  }

  /// Switches the page-level window and recomputes every section that was
  /// already showing data, so visible tabs update immediately; not-yet-opened
  /// tabs just pick up the new [timeframe] naturally when first visited.
  Future<void> setTimeframe(StatsTimeframe value) async {
    if (timeframe.value == value) return;
    timeframe.value = value;

    final toRecompute = <StatsStage>[
      if (stats.value?.overview != null) StatsStage.computingOverview,
      if (stats.value?.activity != null) StatsStage.computingActivity,
      if (stats.value?.engagement != null) StatsStage.computingEngagement,
      if (stats.value?.content != null) StatsStage.computingContent,
    ];
    if (toRecompute.isEmpty) return;

    stats.value = _cacheKey == null
        ? null
        : ChatStats(sourceMessageCount: _cacheKey!.count, sourceLatestMillis: _cacheKey!.latestMillis);

    for (final stage in toRecompute) {
      await ensureSection(stage, force: true);
    }
  }

  Future<ContentStats> _computeContent() async {
    final coverage = await runAsync(() => ChatStatsQueries.textCoverage(chat));
    final cap = tier == StatsDetailTier.large ? kContentMessageCapLarge : kContentMessageCap;
    final myTexts = await runAsync(() => ChatStatsQueries.recentTexts(chat, fromMe: true, limit: cap));
    final theirTexts = await runAsync(() => ChatStatsQueries.recentTexts(chat, fromMe: false, limit: cap));
    final windowed = myTexts.length >= cap || theirTexts.length >= cap;
    // Scoped to the page-level timeframe (unlike the rest of Content, which
    // reads full history) — the longest/shortest leaderboards should honor
    // the same window the other tabs do.
    final lengthsByParticipant = await runAsync(
      () => ChatStatsQueries.textLengthsByParticipant(
        chat,
        sinceMillis: timeframe.value.cutoffMillis(),
        limitPerParticipant: cap,
      ),
    );
    final reactions = await runAsync(() => ChatStatsQueries.reactions(chat));
    final mimeTypes = await runAsync(() => ChatStatsQueries.attachmentMimeTypes(chat));
    final effectIds = await runAsync(() => ChatStatsQueries.expressiveSendStyleIds(chat));
    final edited = await runAsync(() => ChatStatsQueries.editedCount(chat));
    final unsent = await runAsync(() => ChatStatsQueries.unsentCount(chat));
    final audio = await runAsync(() => ChatStatsQueries.audioStats(chat));

    return _isolateContent(
      myTexts: myTexts,
      theirTexts: theirTexts,
      lengthsByParticipant: lengthsByParticipant,
      reactions: reactions,
      attachmentMimeTypes: mimeTypes,
      expressiveSendStyleIds: effectIds,
      editedCount: edited,
      unsentCount: unsent,
      audioSent: audio.sent,
      audioReceived: audio.received,
      audioPlayedRatio: audio.playedOfReceived,
      textCoverage: coverage,
      windowed: windowed,
    );
  }

  /// Group event timeline — cheap, single query, no isolate hop needed.
  Future<List<GroupEventRecord>> loadGroupEvents() => runAsync(() => ChatStatsQueries.groupEvents(chat));

  /// Opt-in who-reacts-to-whom matrix (Members tab). Not part of [stats] / the
  /// cache — it's windowed and explicitly user-triggered, so it's held only
  /// for the life of this controller.
  final Rxn<ReactionMatrixStats> reactionMatrix = Rxn<ReactionMatrixStats>();
  final RxBool reactionMatrixLoading = false.obs;

  Future<void> computeReactionMatrixFor({int months = 6}) async {
    if (reactionMatrixLoading.value) return;
    reactionMatrixLoading.value = true;
    try {
      final since = DateTime.now().subtract(Duration(days: months * 30)).millisecondsSinceEpoch;
      final raw = await runAsync(() => ChatStatsQueries.reactionMatrixData(chat, sinceMillis: since));
      final ids = [kMeParticipantId, ...await runAsync(() => ChatStatsQueries.participantHandleIds(chat))];
      reactionMatrix.value = await _isolateReactionMatrix(
        reactionRows: raw.reactionRows,
        guidToSender: raw.guidToSender,
        participantIds: ids,
        windowMonths: months,
      );
    } catch (e, s) {
      Logger.error('Failed to compute reaction matrix', error: e, trace: s, tag: 'ChatStats');
    } finally {
      reactionMatrixLoading.value = false;
    }
  }

  /// A single participant's `ActivityStats`, scoped to just their timestamps —
  /// backs the per-participant deep dive. Reuses the already-fetched
  /// `_byParticipant` map rather than issuing a new DB query.
  Future<ActivityStats> activityForParticipant(int participantId) async {
    _byParticipant ??= await runAsync(() => ChatStatsQueries.timestampsByParticipant(chat));
    final timestamps = _byParticipant![participantId] ?? const <int>[];
    return _isolateActivity(byParticipant: {participantId: timestamps});
  }

  /// Resolves display names/avatars once per participant id. The computer
  /// never sees names — only ids — which is what keeps it isolate-portable.
  Future<void> _resolveParticipants() async {
    final ids = await runAsync(() => ChatStatsQueries.participantHandleIds(chat));
    final resolved = <int, ParticipantInfo>{
      kMeParticipantId: const ParticipantInfo(id: kMeParticipantId, displayName: 'You'),
    };
    for (final id in ids) {
      final handle = await runAsync(() => Database.handles.get(id));
      if (handle == null) continue;
      final handleState = HandleSvc.getOrCreateHandleState(handle);
      resolved[id] = ParticipantInfo(
        id: id,
        displayName: handleState.displayName.value ?? handle.address,
        address: handle.address,
      );
    }
    participants.value = resolved;
  }

  @override
  void onClose() {
    // Largest object here — hold it and it's a real leak on big chats.
    _byParticipant = null;
    super.onClose();
  }

  // ── Isolate entry points ──────────────────────────────────────────────
  //
  // Each of these MUST be `static` with no instance-field access anywhere in
  // its body. `Isolate.run(() => ...)` closures created inside an *instance*
  // method share a compiler-generated context with every other closure in
  // that method — including ones that read `this.chat` / `this._byParticipant`
  // — so the isolate closure ends up transitively holding a reference to
  // `this` (a GetxController, full of unsendable listeners) even though it
  // never reads it. That fails at the isolate boundary with "object is
  // unsendable". Keeping these as static methods with only value parameters
  // is what keeps the closures actually isolate-safe.

  static Future<OverviewStats> _isolateOverview({
    required Map<int, List<int>> byParticipant,
    required int attachments,
    required int unattributedCount,
  }) {
    return Isolate.run(() => computeOverview(
          byParticipant: byParticipant,
          attachments: attachments,
          unattributedCount: unattributedCount,
        ));
  }

  static Future<ActivityStats> _isolateActivity({required Map<int, List<int>> byParticipant}) {
    return Isolate.run(() => computeActivity(byParticipant: byParticipant));
  }

  static Future<EngagementStats> _isolateEngagement({
    required Map<int, List<int>> byParticipant,
    required List<int> readMillis,
    required bool isGroup,
  }) {
    return Isolate.run(() => computeEngagement(
          byParticipant: byParticipant,
          readMillis: readMillis,
          isGroup: isGroup,
        ));
  }

  static Future<ContentStats> _isolateContent({
    required List<String> myTexts,
    required List<String> theirTexts,
    required Map<int, List<int>> lengthsByParticipant,
    required List<({String type, bool fromMe})> reactions,
    required List<String> attachmentMimeTypes,
    required List<String> expressiveSendStyleIds,
    required int editedCount,
    required int unsentCount,
    required int audioSent,
    required int audioReceived,
    required double? audioPlayedRatio,
    required double textCoverage,
    required bool windowed,
  }) {
    return Isolate.run(() => computeContent(
          myTexts: myTexts,
          theirTexts: theirTexts,
          lengthsByParticipant: lengthsByParticipant,
          reactions: reactions,
          attachmentMimeTypes: attachmentMimeTypes,
          expressiveSendStyleIds: expressiveSendStyleIds,
          editedCount: editedCount,
          unsentCount: unsentCount,
          audioSent: audioSent,
          audioReceived: audioReceived,
          audioPlayedRatio: audioPlayedRatio,
          textCoverage: textCoverage,
          windowed: windowed,
        ));
  }

  static Future<ReactionMatrixStats> _isolateReactionMatrix({
    required List<ReactionMatrixRow> reactionRows,
    required Map<String, int> guidToSender,
    required List<int> participantIds,
    required int windowMonths,
  }) {
    return Isolate.run(() => computeReactionMatrix(
          reactionRows: reactionRows,
          guidToSender: guidToSender,
          participantIds: participantIds,
          windowMonths: windowMonths,
        ));
  }
}
