/// Sentinel participant id for the local user. Real participants use `Handle.id`,
/// which ObjectBox always assigns > 0.
const int kMeParticipantId = -1;

/// Sentinel for an incoming message with no resolvable sender handle (see
/// `ChatStatsQueries.unattributedCount`). Distinct from [kMeParticipantId] so
/// it never gets attributed to "me" or collapses into a real participant.
const int kUnattributedParticipantId = -3;

/// Sentinel value for the "Whole Group" option in the comparison-target
/// selector (`ComparisonSelector`). Only used at the selector's dialog
/// boundary — `showBBListSelector` returns `null` for both "dismissed with no
/// selection" and "selected a `null` option", so `null` can't itself be a
/// choosable option value. `ChatStatsController.comparisonParticipantId`
/// still uses `null` internally to mean "whole group".
const int kWholeGroupComparisonId = -4;

/// The silence that separates one conversation "session" from the next. Used
/// for session segmentation, openers/enders, and response-time outlier filtering.
const int kSessionGapMillis = 6 * 60 * 60 * 1000; // 6 hours

/// Below this, `dateRead` data is too sparse to draw conclusions from — the
/// other party likely has read receipts off. Hide those metrics rather than
/// showing a misleadingly small number.
const double kMinReadReceiptCoverage = 0.5;

/// Minimum samples before a median/p90 is meaningful.
const int kMinResponseSamples = 20;

/// Below this gap, a repeated message from the same participant is rapid-fire
/// — one thought split across bubbles, not a double-text.
const int kDoubleTextGapMillis = 60 * 1000; // 1 minute

enum StatsStage {
  idle,
  loadingMessages,
  computingOverview,
  computingActivity,
  computingEngagement,
  computingContent,
  done,
}

class ChatStatsProgress {
  final StatsStage stage;

  /// 0.0–1.0 where known; null for indeterminate stages (render a spinner
  /// rather than a bar).
  final double? fraction;

  const ChatStatsProgress(this.stage, [this.fraction]);
  static const idle = ChatStatsProgress(StatsStage.idle);

  String get label => switch (stage) {
        StatsStage.loadingMessages => 'Loading messages...',
        StatsStage.computingOverview => 'Crunching totals...',
        StatsStage.computingActivity => 'Mapping activity...',
        StatsStage.computingEngagement => 'Analyzing responses...',
        StatsStage.computingContent => 'Reading message content...',
        _ => '',
      };
}

/// Page-level window applied to every section's underlying query — changing
/// this re-scopes totals, charts, and per-participant metrics to just this
/// span ending now. Distinct from the Activity tab's own chart-zoom controls,
/// which only slice an already-fetched (and already timeframe-scoped) series
/// for display.
enum StatsTimeframe { day, week, month, threeMonths, sixMonths, year, all }

extension StatsTimeframeX on StatsTimeframe {
  String get label => switch (this) {
        StatsTimeframe.day => '1D',
        StatsTimeframe.week => '1W',
        StatsTimeframe.month => '1M',
        StatsTimeframe.threeMonths => '3M',
        StatsTimeframe.sixMonths => '6M',
        StatsTimeframe.year => '1Y',
        StatsTimeframe.all => 'All',
      };

  /// Full-word phrasing for section headers (e.g. the Overview volume
  /// sparkline), as opposed to [label]'s compact chip text.
  String get longLabel => switch (this) {
        StatsTimeframe.day => 'Today',
        StatsTimeframe.week => 'Last 7 Days',
        StatsTimeframe.month => 'Last 30 Days',
        StatsTimeframe.threeMonths => 'Last 3 Months',
        StatsTimeframe.sixMonths => 'Last 6 Months',
        StatsTimeframe.year => 'Last Year',
        StatsTimeframe.all => 'All Time',
      };

  /// Epoch millis marking the start of the window (inclusive), or `null` for
  /// "all time" — callers treat `null` as "no lower bound".
  int? cutoffMillis({DateTime? now}) {
    if (this == StatsTimeframe.all) return null;
    final days = switch (this) {
      StatsTimeframe.day => 1,
      StatsTimeframe.week => 7,
      StatsTimeframe.month => 30,
      StatsTimeframe.threeMonths => 90,
      StatsTimeframe.sixMonths => 182,
      StatsTimeframe.year => 365,
      StatsTimeframe.all => throw StateError('unreachable'),
    };
    return (now ?? DateTime.now()).subtract(Duration(days: days)).millisecondsSinceEpoch;
  }
}

/// Drives how much work the page does up front. See the main plan.
enum StatsDetailTier { small, medium, large }

StatsDetailTier tierFor(int messageCount) => messageCount < 5000
    ? StatsDetailTier.small
    : messageCount < 50000
        ? StatsDetailTier.medium
        : StatsDetailTier.large;

/// Display metadata for one participant. Resolved on the UI side from
/// `ContactsSvcV2`; the computer only ever sees ids.
class ParticipantInfo {
  final int id; // kMeParticipantId for the local user
  final String displayName;
  final String? address;

  bool get isMe => id == kMeParticipantId;
  const ParticipantInfo({required this.id, required this.displayName, this.address});
}

class ParticipantCount {
  final int participantId;
  final int count;
  const ParticipantCount(this.participantId, this.count);
}

/// A bucketed point in a time series. [byParticipant] carries the per-sender
/// split; [total] is the sum. 1:1 charts read two entries, group charts read N.
class TimeBucket {
  final int startMillis;
  final Map<int, int> byParticipant;
  const TimeBucket({required this.startMillis, required this.byParticipant});

  int get total => byParticipant.values.fold(0, (a, b) => a + b);
  int get sent => byParticipant[kMeParticipantId] ?? 0;
  int get received => total - sent;
}

enum StatsBucketSize { day, week, month }

class OverviewStats {
  final int total;
  final int sent;
  final int received;
  final int attachments;
  final double averagePerDay;
  final int currentStreak;
  final int longestStreak;

  /// Incoming messages with no resolvable sender handle — excluded from
  /// [leaderboard] and every per-participant metric because there's no id to
  /// key them by. Non-zero means those metrics under-report; the UI must
  /// surface this rather than silently dropping them (see Task 12).
  final int unattributedCount;

  /// Descending by count. Includes the local user. For a 1:1 chat this has two
  /// entries and drives the two-segment balance bar; for a group it drives the
  /// N-segment bar and the leaderboard.
  final List<ParticipantCount> leaderboard;

  /// Retained for series bounds and the "busiest day" lookup — not shown as a
  /// "talking since" tile. Scoped to the page-level [StatsTimeframe] window
  /// like the rest of [OverviewStats] — do not use this for a "first message
  /// ever" display; see [firstTrackedMessageMillis] for that.
  final int? firstMessageMillis;
  final int? lastMessageMillis;

  /// Absolute earliest "real" message across the chat's full history —
  /// unlike [firstMessageMillis], never scoped to the selected timeframe.
  /// Backs the Overview tab's "first message we've tracked" note.
  final int? firstTrackedMessageMillis;

  const OverviewStats({
    required this.total,
    required this.sent,
    required this.received,
    required this.attachments,
    required this.averagePerDay,
    required this.currentStreak,
    required this.longestStreak,
    required this.unattributedCount,
    required this.leaderboard,
    this.firstMessageMillis,
    this.lastMessageMillis,
    this.firstTrackedMessageMillis,
  });
}

class ActivityStats {
  final List<int> byHour; // 24 entries, index = local hour
  final List<int> byWeekday; // 7 entries, index 0 = Monday
  final List<List<int>> weekdayHourGrid; // [weekday][hour]
  final Map<int, int> byDay; // local-midnight millis → count
  final int? busiestDayMillis;
  final int busiestDayCount;
  final int peakHour;
  final double nightOwlRatio; // share sent 00:00–04:00 local
  final List<TimeBucket> dailySeries;

  const ActivityStats({
    required this.byHour,
    required this.byWeekday,
    required this.weekdayHourGrid,
    required this.byDay,
    this.busiestDayMillis,
    required this.busiestDayCount,
    required this.peakHour,
    required this.nightOwlRatio,
    required this.dailySeries,
  });
}

class ResponseTimeStats {
  final int? medianMillis; // null when below kMinResponseSamples
  final int? p90Millis;
  final List<int> histogram; // aligned with kResponseBucketLabels
  final int sampleCount;
  const ResponseTimeStats({
    this.medianMillis,
    this.p90Millis,
    required this.histogram,
    required this.sampleCount,
  });
  static const empty = ResponseTimeStats(histogram: [0, 0, 0, 0, 0, 0], sampleCount: 0);
}

const kResponseBucketLabels = ['<1m', '1–5m', '5–30m', '30m–2h', '2–12h', '12h+'];

class EngagementStats {
  /// Keyed by participant id — one entry per person, including me. In a 1:1
  /// this is two entries; the UI reads them as "you" and "them".
  final Map<int, ResponseTimeStats> responseTimes;
  final Map<int, int> sessionsStarted;
  final Map<int, int> sessionsEnded;
  final Map<int, int> doubleTexts;

  final int? longestSilenceMillis;
  final int? longestSilenceStartMillis;

  /// Rolling share per participant over time. 1:1 renders a single ratio line;
  /// groups render a stacked area.
  final List<TimeBucket> balanceDrift;

  /// 1:1 only — `dateRead` has no per-participant breakdown, so these are null
  /// for group chats and their UI section is hidden entirely.
  final double? readReceiptCoverage;
  final int? leftOnReadCount;

  const EngagementStats({
    required this.responseTimes,
    required this.sessionsStarted,
    required this.sessionsEnded,
    required this.doubleTexts,
    this.longestSilenceMillis,
    this.longestSilenceStartMillis,
    required this.balanceDrift,
    this.readReceiptCoverage,
    this.leftOnReadCount,
  });
}

/// Sections are nullable because they are computed lazily and independently.
/// A null section means "not computed yet", which is distinct from "computed
/// and empty" — the UI needs both states.
class ChatStats {
  final OverviewStats? overview;
  final ActivityStats? activity;
  final EngagementStats? engagement;
  final ContentStats? content;

  final int sourceMessageCount;
  final int sourceLatestMillis;

  const ChatStats({
    this.overview,
    this.activity,
    this.engagement,
    this.content,
    required this.sourceMessageCount,
    required this.sourceLatestMillis,
  });

  ChatStats copyWith({
    OverviewStats? overview,
    ActivityStats? activity,
    EngagementStats? engagement,
    ContentStats? content,
    int? sourceMessageCount,
    int? sourceLatestMillis,
  }) {
    return ChatStats(
      overview: overview ?? this.overview,
      activity: activity ?? this.activity,
      engagement: engagement ?? this.engagement,
      content: content ?? this.content,
      sourceMessageCount: sourceMessageCount ?? this.sourceMessageCount,
      sourceLatestMillis: sourceLatestMillis ?? this.sourceLatestMillis,
    );
  }
}

/// Cap on how many of each side's messages the Content tab reads full text
/// for — this is the only tab that touches full message bodies. Halved on
/// large-tier chats. See Task 11.
const int kContentMessageCap = 8000;
const int kContentMessageCapLarge = 3000;

const kContentLengthBucketLabels = ['<10', '10–30', '30–100', '100–300', '300+'];

class EmojiCount {
  final String emoji;
  final int mineCount;
  final int theirsCount;
  const EmojiCount(this.emoji, this.mineCount, this.theirsCount);
  int get total => mineCount + theirsCount;
}

class WordCount {
  final String word;
  final int count;
  const WordCount(this.word, this.count);
}

/// One curse word's mine/theirs split — feeds the "Colorful Language" bar
/// chart. Mirrors [EmojiCount]'s shape since both are a mine-vs-theirs
/// frequency count rendered the same way.
class SwearCount {
  final String word;
  final int mineCount;
  final int theirsCount;
  const SwearCount(this.word, this.mineCount, this.theirsCount);
  int get total => mineCount + theirsCount;
}

/// Minimum texted-message samples before a participant's average length is
/// meaningful enough to rank — keeps one-off messages from a rarely-active
/// participant from dominating the longest/shortest leaderboards.
const int kMinLengthSamples = 5;

/// One participant's average message length, feeding the longest/shortest
/// message-length leaderboards. [messageCount] is how many texted messages
/// the average was computed over (post [kMinLengthSamples] filtering upstream).
class ParticipantLengthStats {
  final int participantId;
  final double avgLength;
  final int messageCount;
  const ParticipantLengthStats({required this.participantId, required this.avgLength, required this.messageCount});
}

class ContentStats {
  /// Share of messages with non-null `text` at analysis time (Task 11 gate).
  final double textCoverage;

  /// True when the analyzed set was capped by [kContentMessageCap] rather
  /// than covering full history — drives the "most recent N" caption.
  final bool windowed;
  final int analyzedMessageCount;

  final double avgLengthMine;
  final double avgLengthTheirs;
  final List<int> lengthHistogramMine; // aligned with kContentLengthBucketLabels
  final List<int> lengthHistogramTheirs;

  /// Per-participant average message length, descending by length. Feeds the
  /// longest/shortest message-length leaderboards (a shortest-first read of
  /// the same list). Only participants with at least [kMinLengthSamples]
  /// texted messages are included.
  final List<ParticipantLengthStats> messageLengthLeaderboard;

  /// Descending by total (mine + theirs).
  final List<EmojiCount> topEmoji;

  /// Descending by count, stopword-filtered, 3+ chars, 2+ occurrences.
  final List<WordCount> topWords;

  /// Keyed by normalized `ReactionTypes` name. Net of adds minus removals.
  final Map<String, int> reactionsGivenByType;
  final Map<String, int> reactionsReceivedByType;
  final int reactionsTakenBack;

  /// Keyed by top-level mime category ("image", "video", "audio", ...).
  final Map<String, int> attachmentMimeCounts;

  /// Keyed by raw `expressiveSendStyleId` — the UI maps this to a friendly
  /// name via `effectMap`, matching how bubbles already display effect names.
  final Map<String, int> effectIdCounts;

  final int editedCount;
  final int unsentCount;

  /// [editedCount]/[unsentCount] split by side — feeds the Correction Rate
  /// tiles. Mine is scoped to the local user; theirs honors the same
  /// comparison-target selector as the rest of Content.
  final int editedCountMine;
  final int editedCountTheirs;
  final int unsentCountMine;
  final int unsentCountTheirs;

  /// Total sent/received message counts (not just texted ones) — the
  /// denominators for [correctionRateMine]/[correctionRateTheirs]. `theirs`
  /// honors the comparison-target selector, matching [editedCountTheirs].
  final int sentCountMine;
  final int receivedCountTheirs;

  final int audioSent;
  final int audioReceived;
  final double? audioPlayedRatio; // null when nothing was received

  /// Descending by total (mine + theirs). Curated curse-word vocabulary —
  /// see `_kSwearWords` in the computer.
  final List<SwearCount> topSwearWords;

  /// Share of my sent messages later edited or unsent. `null` when I haven't
  /// sent anything in this window.
  double? get correctionRateMine => sentCountMine == 0 ? null : (editedCountMine + unsentCountMine) / sentCountMine;

  /// Share of the comparison target's received messages later edited or
  /// unsent. `null` when nothing was received from them in this window.
  double? get correctionRateTheirs =>
      receivedCountTheirs == 0 ? null : (editedCountTheirs + unsentCountTheirs) / receivedCountTheirs;

  const ContentStats({
    required this.textCoverage,
    required this.windowed,
    required this.analyzedMessageCount,
    required this.avgLengthMine,
    required this.avgLengthTheirs,
    required this.lengthHistogramMine,
    required this.lengthHistogramTheirs,
    required this.messageLengthLeaderboard,
    required this.topEmoji,
    required this.topWords,
    required this.reactionsGivenByType,
    required this.reactionsReceivedByType,
    required this.reactionsTakenBack,
    required this.attachmentMimeCounts,
    required this.effectIdCounts,
    required this.editedCount,
    required this.unsentCount,
    required this.editedCountMine,
    required this.editedCountTheirs,
    required this.unsentCountMine,
    required this.unsentCountTheirs,
    required this.sentCountMine,
    required this.receivedCountTheirs,
    required this.audioSent,
    required this.audioReceived,
    required this.topSwearWords,
    this.audioPlayedRatio,
  });
}

/// A group-membership/name/photo event — `itemType != 0`, deliberately
/// excluded from every other metric. `senderId` is `kMeParticipantId`,
/// `kUnattributedParticipantId`, or a `Handle.id`.
class GroupEventRecord {
  final int itemType; // 1 = participant add/remove, 2 = name change, 3 = photo change
  final int groupActionType;
  final String? groupTitle;
  final int dateMillis;
  final int senderId;

  const GroupEventRecord({
    required this.itemType,
    required this.groupActionType,
    this.groupTitle,
    required this.dateMillis,
    required this.senderId,
  });
}

/// One raw reaction row feeding the who-reacts-to-whom matrix: the reactor
/// plus the guid of the message they reacted to (sender resolved separately
/// via a guid→sender map — see `ChatStatsQueries.reactionMatrixData`).
class ReactionMatrixRow {
  final String targetGuid;
  final int reactorId;
  final String type; // raw, possibly `-`-prefixed
  const ReactionMatrixRow({required this.targetGuid, required this.reactorId, required this.type});
}

/// Square reactor×target matrix. Self-reactions land on the diagonal — legal
/// in iMessage, rendered rather than assumed away.
class ReactionMatrixStats {
  final List<int> participantIds; // shared row/column order
  final List<List<int>> matrix; // matrix[reactorIndex][targetIndex]
  final int windowMonths;

  const ReactionMatrixStats({
    required this.participantIds,
    required this.matrix,
    required this.windowMonths,
  });

  int get total => matrix.expand((row) => row).fold(0, (a, b) => a + b);
}
