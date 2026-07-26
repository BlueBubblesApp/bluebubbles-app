import 'package:bluebubbles/helpers/ui/reaction_helpers.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_models.dart';
import 'package:characters/characters.dart';

/// Walks per-participant ascending timestamp lists as a single chronological
/// stream, calling [onMessage] with each message's participant id.
///
/// Ties resolve to the lowest participant id, which puts the local user
/// (kMeParticipantId == -1) first. Arbitrary, but must stay stable — response
/// time and double-texting both key off sender transitions.
void mergeWalk(
  Map<int, List<int>> byParticipant,
  void Function(int millis, int participantId) onMessage,
) {
  final ids = byParticipant.keys.toList()..sort();
  final cursors = List<int>.filled(ids.length, 0);

  while (true) {
    int bestIdx = -1;
    int bestMillis = 0;
    for (var i = 0; i < ids.length; i++) {
      final list = byParticipant[ids[i]]!;
      if (cursors[i] >= list.length) continue;
      final v = list[cursors[i]];
      if (bestIdx == -1 || v < bestMillis) {
        bestIdx = i;
        bestMillis = v;
      }
    }
    if (bestIdx == -1) break;
    cursors[bestIdx]++;
    onMessage(bestMillis, ids[bestIdx]);
  }
}

/// Local midnight for a timestamp — the canonical day bucket key.
int dayKey(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
}

OverviewStats computeOverview({
  required Map<int, List<int>> byParticipant,
  required int attachments,
  required int unattributedCount,
}) {
  int total = 0;
  final leaderboard = <ParticipantCount>[];
  for (final entry in byParticipant.entries) {
    total += entry.value.length;
    leaderboard.add(ParticipantCount(entry.key, entry.value.length));
  }
  leaderboard.sort((a, b) => b.count.compareTo(a.count));

  final sent = byParticipant[kMeParticipantId]?.length ?? 0;
  final received = total - sent;

  int? firstMillis;
  int? lastMillis;
  for (final list in byParticipant.values) {
    if (list.isEmpty) continue;
    if (firstMillis == null || list.first < firstMillis) firstMillis = list.first;
    if (lastMillis == null || list.last > lastMillis) lastMillis = list.last;
  }

  double averagePerDay = 0;
  if (firstMillis != null && lastMillis != null && total > 0) {
    final firstDay = DateTime.fromMillisecondsSinceEpoch(firstMillis);
    final lastDay = DateTime.fromMillisecondsSinceEpoch(lastMillis);
    final spanDays = DateTime(lastDay.year, lastDay.month, lastDay.day)
            .difference(DateTime(firstDay.year, firstDay.month, firstDay.day))
            .inDays +
        1;
    averagePerDay = total / (spanDays < 1 ? 1 : spanDays);
  }

  // Build the sorted set of distinct day keys across all participants for streaks.
  final dayKeys = <int>{};
  for (final list in byParticipant.values) {
    for (final millis in list) {
      dayKeys.add(dayKey(millis));
    }
  }
  final sortedDays = dayKeys.toList()..sort();

  int longestStreak = 0;
  int runningStreak = 0;
  int? prevDay;
  for (final day in sortedDays) {
    if (prevDay == null) {
      runningStreak = 1;
    } else {
      final p = DateTime.fromMillisecondsSinceEpoch(prevDay);
      final expected = DateTime(p.year, p.month, p.day + 1);
      final isConsecutive = expected.millisecondsSinceEpoch == day;
      runningStreak = isConsecutive ? runningStreak + 1 : 1;
    }
    if (runningStreak > longestStreak) longestStreak = runningStreak;
    prevDay = day;
  }

  int currentStreak = 0;
  if (sortedDays.isNotEmpty) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final yesterday = DateTime(now.year, now.month, now.day - 1).millisecondsSinceEpoch;
    final lastDay = sortedDays.last;
    if (lastDay == today || lastDay == yesterday) {
      currentStreak = 1;
      for (var i = sortedDays.length - 1; i > 0; i--) {
        final d = DateTime.fromMillisecondsSinceEpoch(sortedDays[i - 1]);
        final expected = DateTime(d.year, d.month, d.day + 1);
        if (expected.millisecondsSinceEpoch == sortedDays[i]) {
          currentStreak++;
        } else {
          break;
        }
      }
    }
  }

  return OverviewStats(
    total: total,
    sent: sent,
    received: received,
    attachments: attachments,
    averagePerDay: averagePerDay,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    unattributedCount: unattributedCount,
    leaderboard: leaderboard,
    firstMessageMillis: firstMillis,
    lastMessageMillis: lastMillis,
  );
}

ActivityStats computeActivity({required Map<int, List<int>> byParticipant}) {
  final byHour = List<int>.filled(24, 0);
  final byWeekday = List<int>.filled(7, 0);
  final grid = List.generate(7, (_) => List<int>.filled(24, 0));
  final byDay = <int, int>{};
  final dayParticipant = <int, Map<int, int>>{};

  int total = 0;
  mergeWalk(byParticipant, (millis, participantId) {
    total++;
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    final wd = d.weekday - 1; // 0 = Monday
    byHour[d.hour]++;
    byWeekday[wd]++;
    grid[wd][d.hour]++;
    final key = dayKey(millis);
    byDay.update(key, (v) => v + 1, ifAbsent: () => 1);
    final perParticipant = dayParticipant.putIfAbsent(key, () => <int, int>{});
    perParticipant.update(participantId, (v) => v + 1, ifAbsent: () => 1);
  });

  int peakHour = 0;
  for (var i = 1; i < 24; i++) {
    if (byHour[i] > byHour[peakHour]) peakHour = i;
  }

  int? busiestDayMillis;
  int busiestDayCount = 0;
  for (final entry in byDay.entries) {
    if (entry.value > busiestDayCount) {
      busiestDayCount = entry.value;
      busiestDayMillis = entry.key;
    }
  }

  double nightOwlRatio = 0;
  if (total > 0) {
    final nightCount = byHour[0] + byHour[1] + byHour[2] + byHour[3];
    nightOwlRatio = nightCount / total;
  }

  final dailySeries = _gapFilledDailySeries(dayParticipant);

  return ActivityStats(
    byHour: byHour,
    byWeekday: byWeekday,
    weekdayHourGrid: grid,
    byDay: byDay,
    busiestDayMillis: busiestDayMillis,
    busiestDayCount: busiestDayCount,
    peakHour: peakHour,
    nightOwlRatio: nightOwlRatio,
    dailySeries: dailySeries,
  );
}

/// Emits one `TimeBucket` per calendar day spanning first→last day, with
/// zero-filled days for silences — a line chart over a sparse map would
/// otherwise draw a straight line across a three-month gap and hide it.
List<TimeBucket> _gapFilledDailySeries(Map<int, Map<int, int>> dayParticipant) {
  if (dayParticipant.isEmpty) return const [];

  final days = dayParticipant.keys.toList()..sort();
  final firstDay = DateTime.fromMillisecondsSinceEpoch(days.first);
  final lastDay = DateTime.fromMillisecondsSinceEpoch(days.last);

  final result = <TimeBucket>[];
  var cursor = DateTime(firstDay.year, firstDay.month, firstDay.day);
  final end = DateTime(lastDay.year, lastDay.month, lastDay.day);
  while (!cursor.isAfter(end)) {
    final key = cursor.millisecondsSinceEpoch;
    result.add(TimeBucket(startMillis: key, byParticipant: dayParticipant[key] ?? const {}));
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return result;
}

const int _kMaxBucketPoints = 400;

/// Re-buckets a daily series to week/month granularity. Never DB-backed — this
/// is what makes the UI's bucket toggle instant. Week starts Monday, matching
/// `byWeekday`. Caps output to ~400 points, widening the bucket automatically
/// if the requested size would exceed that.
List<TimeBucket> rebucket(List<TimeBucket> daily, StatsBucketSize size) {
  if (daily.isEmpty) return const [];

  var effectiveSize = size;
  if (effectiveSize == StatsBucketSize.day && daily.length > _kMaxBucketPoints) {
    effectiveSize = StatsBucketSize.week;
  }
  if (effectiveSize == StatsBucketSize.week && (daily.length / 7).ceil() > _kMaxBucketPoints) {
    effectiveSize = StatsBucketSize.month;
  }

  if (effectiveSize == StatsBucketSize.day) return daily;

  final buckets = <int, Map<int, int>>{};
  final bucketStarts = <int>[];
  for (final day in daily) {
    final d = DateTime.fromMillisecondsSinceEpoch(day.startMillis);
    late DateTime bucketStart;
    if (effectiveSize == StatsBucketSize.week) {
      final mondayOffset = d.weekday - 1; // 0 = Monday
      bucketStart = DateTime(d.year, d.month, d.day - mondayOffset);
    } else {
      bucketStart = DateTime(d.year, d.month, 1);
    }
    final key = bucketStart.millisecondsSinceEpoch;
    if (!buckets.containsKey(key)) bucketStarts.add(key);
    final bucket = buckets.putIfAbsent(key, () => <int, int>{});
    for (final entry in day.byParticipant.entries) {
      bucket.update(entry.key, (v) => v + entry.value, ifAbsent: () => entry.value);
    }
  }

  bucketStarts.sort();
  return bucketStarts
      .map((key) => TimeBucket(startMillis: key, byParticipant: buckets[key]!))
      .toList();
}

/// Response-time histogram bucket index, aligned with `kResponseBucketLabels`.
int _histogramBucket(int deltaMillis) {
  final minutes = deltaMillis / 60000;
  if (minutes < 1) return 0;
  if (minutes < 5) return 1;
  if (minutes < 30) return 2;
  if (minutes < 120) return 3;
  if (minutes < 720) return 4; // 12h
  return 5;
}

({int median, int p90}) _percentiles(List<int> sorted) {
  int pick(double p) {
    final idx = (p * (sorted.length - 1)).round();
    return sorted[idx.clamp(0, sorted.length - 1)];
  }

  return (median: pick(0.5), p90: pick(0.9));
}

const int _kMaxDriftPoints = 104;

/// My sent messages that were read, followed by a silence exceeding
/// `kSessionGapMillis` before the next message from anyone. A read timestamp
/// landing inside such a gap is sufficient evidence — see Task 05 notes on
/// why the precise per-message version isn't worth the alignment risk.
int _computeLeftOnRead(Map<int, List<int>> byParticipant, List<int> readMillis) {
  if (readMillis.isEmpty) return 0;

  final allMillis = <int>[];
  mergeWalk(byParticipant, (millis, id) => allMillis.add(millis));

  var count = 0;
  var readIdx = 0;
  for (var i = 0; i < allMillis.length - 1; i++) {
    final gapStart = allMillis[i];
    final gapEnd = allMillis[i + 1];
    if (gapEnd - gapStart <= kSessionGapMillis) continue;

    while (readIdx < readMillis.length && readMillis[readIdx] < gapStart) {
      readIdx++;
    }
    while (readIdx < readMillis.length && readMillis[readIdx] <= gapEnd) {
      count++;
      readIdx++;
    }
  }
  return count;
}

EngagementStats computeEngagement({
  required Map<int, List<int>> byParticipant,
  required List<int> readMillis,
  required bool isGroup,
}) {
  final ids = byParticipant.keys.toList();
  final medianSamples = <int, List<int>>{for (final id in ids) id: <int>[]};
  final histogramSamples = <int, List<int>>{for (final id in ids) id: <int>[]};
  // Pre-seeded with every participant so callers always see N+1 entries, even
  // for someone who never happened to open a session or double-text.
  final sessionsStarted = <int, int>{for (final id in ids) id: 0};
  final sessionsEnded = <int, int>{for (final id in ids) id: 0};
  final doubleTexts = <int, int>{for (final id in ids) id: 0};
  final dayParticipant = <int, Map<int, int>>{};

  int? longestSilenceMillis;
  int? longestSilenceStartMillis;

  int? lastMillis;
  int? lastId;
  int? runLastMillis;
  int? runParticipant;
  bool runCounted = false;

  mergeWalk(byParticipant, (millis, id) {
    // Response times: a reply is a message following a different participant.
    if (lastId != null && lastId != id) {
      final delta = millis - lastMillis!;
      histogramSamples[id]!.add(delta);
      // A reply after a multi-hour silence is really a new conversation
      // opener, not a response — keep the median/p90 sample set filtered.
      if (delta <= kSessionGapMillis) medianSamples[id]!.add(delta);
    }

    // Sessions: a message opens a session if it's first or follows a gap
    // exceeding kSessionGapMillis; the previous message ends the prior one.
    final isOpener = lastMillis == null || (millis - lastMillis!) > kSessionGapMillis;
    if (isOpener) {
      sessionsStarted.update(id, (v) => v + 1, ifAbsent: () => 1);
      if (lastId != null) sessionsEnded.update(lastId!, (v) => v + 1, ifAbsent: () => 1);
    }

    // Longest silence between any two consecutive messages.
    if (lastMillis != null) {
      final gap = millis - lastMillis!;
      if (longestSilenceMillis == null || gap > longestSilenceMillis!) {
        longestSilenceMillis = gap;
        longestSilenceStartMillis = lastMillis;
      }
    }

    // Double-texting: a run of >=2 consecutive messages from the same
    // participant counts as one event, only once the gap between two of them
    // exceeds kDoubleTextGapMillis (rapid-fire bubbles are one thought).
    if (runParticipant != id) {
      runParticipant = id;
      runCounted = false;
    } else if (!runCounted && millis - runLastMillis! > kDoubleTextGapMillis) {
      doubleTexts.update(id, (v) => v + 1, ifAbsent: () => 1);
      runCounted = true;
    }
    runLastMillis = millis;

    // Daily per-participant counts feed balance drift below.
    final key = dayKey(millis);
    final perParticipant = dayParticipant.putIfAbsent(key, () => <int, int>{});
    perParticipant.update(id, (v) => v + 1, ifAbsent: () => 1);

    lastMillis = millis;
    lastId = id;
  });
  // The final message ends the last session — count it after the walk so
  // openers and enders reconcile.
  if (lastId != null) sessionsEnded.update(lastId!, (v) => v + 1, ifAbsent: () => 1);

  final responseTimes = <int, ResponseTimeStats>{};
  for (final id in ids) {
    final samples = medianSamples[id]!..sort();
    if (samples.length < kMinResponseSamples) {
      responseTimes[id] = ResponseTimeStats.empty;
      continue;
    }
    final percentiles = _percentiles(samples);
    final histogram = List<int>.filled(kResponseBucketLabels.length, 0);
    for (final delta in histogramSamples[id]!) {
      histogram[_histogramBucket(delta)]++;
    }
    responseTimes[id] = ResponseTimeStats(
      medianMillis: percentiles.median,
      p90Millis: percentiles.p90,
      histogram: histogram,
      sampleCount: samples.length,
    );
  }

  // Balance drift: rebucket the sparse daily series (no gap-filling — a zero
  // point on a silent day is meaningless here) to week granularity, widening
  // to monthly if that would exceed the point cap.
  final sortedDayKeys = dayParticipant.keys.toList()..sort();
  final dailyBuckets = sortedDayKeys
      .map((key) => TimeBucket(startMillis: key, byParticipant: dayParticipant[key]!))
      .toList();
  var balanceDrift = rebucket(dailyBuckets, StatsBucketSize.week);
  if (balanceDrift.length > _kMaxDriftPoints) {
    balanceDrift = rebucket(dailyBuckets, StatsBucketSize.month);
  }

  double? readReceiptCoverage;
  int? leftOnReadCount;
  if (isGroup) {
    // dateRead has no per-participant breakdown — in a group it only means
    // "somebody read it", which would be actively misleading here.
    readReceiptCoverage = null;
    leftOnReadCount = null;
  } else {
    final sent = byParticipant[kMeParticipantId] ?? const <int>[];
    readReceiptCoverage = sent.isEmpty ? 0.0 : readMillis.length / sent.length;
    leftOnReadCount = readReceiptCoverage < kMinReadReceiptCoverage
        ? null
        : _computeLeftOnRead(byParticipant, readMillis);
  }

  return EngagementStats(
    responseTimes: responseTimes,
    sessionsStarted: sessionsStarted,
    sessionsEnded: sessionsEnded,
    doubleTexts: doubleTexts,
    longestSilenceMillis: longestSilenceMillis,
    longestSilenceStartMillis: longestSilenceStartMillis,
    balanceDrift: balanceDrift,
    readReceiptCoverage: readReceiptCoverage,
    leftOnReadCount: leftOnReadCount,
  );
}

// ── Content (Task 11) ──────────────────────────────────────────────────────

/// Codepoints belonging to the common emoji blocks. Approximate — good enough
/// for a "top emoji" stat, not a full Unicode emoji-property table. Applied
/// per grapheme cluster (via `characters`) rather than per code unit, so a
/// ZWJ family sequence or a skin-tone-modified emoji counts as one emoji, not
/// several.
bool _isEmojiRune(int r) =>
    (r >= 0x1F300 && r <= 0x1FAFF) ||
    (r >= 0x2600 && r <= 0x27BF) ||
    (r >= 0x1F1E6 && r <= 0x1F1FF) || // regional indicators (flags)
    r == 0x2764 || // heavy black heart
    r == 0x2B50 || // star
    r == 0x2B55 || // heavy circle
    r == 0x303D; // part alternation mark

Map<String, int> _countEmoji(Iterable<String> texts) {
  final counts = <String, int>{};
  for (final text in texts) {
    for (final cluster in text.characters) {
      if (cluster.runes.any(_isEmojiRune)) {
        counts.update(cluster, (v) => v + 1, ifAbsent: () => 1);
      }
    }
  }
  return counts;
}

const _kStopwords = {
  'the', 'and', 'you', 'that', 'was', 'for', 'are', 'with', 'his', 'her', 'they', 'this', 'have', 'from', 'not',
  'but', 'what', 'all', 'were', 'when', 'your', 'can', 'said', 'there', 'use', 'each', 'which', 'she', 'how',
  'their', 'will', 'would', 'about', 'out', 'many', 'then', 'them', 'these', 'som', 'into', 'has', 'more', 'him',
  'could', 'just', 'like', 'yeah', 'okay', 'lol', 'got', 'get', 'know', 'think', 'going', 'really', 'good', 'well',
  'now', 'here', 'want', 'that\'s', 'it\'s', 'don\'t', 'i\'m', 'yes', 'nah', 'haha', 'hahaha',
  // URL fragments — the word tokenizer splits a link's scheme/host/TLD out as
  // if they were words, which would otherwise crowd out real content.
  'www', 'https', 'http', 'com', 'org', 'net',
  // Filler/noise words with no real content signal — chat-speak that shows up
  // constantly but tells you nothing about what a chat is actually about.
  'gonna', 'wanna', 'gotta', 'kinda', 'sorta', 'idk', 'omg', 'lmao', 'tbh', 'ngl', 'smh', 'btw', 'imo', 'rn',
  'dont', 'didnt', 'wasnt', 'cant', 'wont', 'isnt', 'arent', 'doesnt', 'couldnt', 'wouldnt', 'shouldnt', 'hasnt',
  'havent', 'thats', 'whats', 'lets', 'ive', 'im', 'ill', 'youre', 'theyre',
};

final _wordPattern = RegExp(r"[a-zA-Z']+");

Map<String, int> _countWords(Iterable<String> texts) {
  final counts = <String, int>{};
  for (final text in texts) {
    for (final match in _wordPattern.allMatches(text.toLowerCase())) {
      final w = match.group(0)!;
      if (w.length < 3 || _kStopwords.contains(w)) continue;
      counts.update(w, (v) => v + 1, ifAbsent: () => 1);
    }
  }
  return counts;
}

int _lengthBucket(int length) {
  if (length < 10) return 0;
  if (length < 30) return 1;
  if (length < 100) return 2;
  if (length < 300) return 3;
  return 4;
}

({double avg, List<int> histogram}) _lengthStats(List<String> texts) {
  final histogram = List<int>.filled(kContentLengthBucketLabels.length, 0);
  if (texts.isEmpty) return (avg: 0, histogram: histogram);
  var total = 0;
  for (final t in texts) {
    total += t.length;
    histogram[_lengthBucket(t.length)]++;
  }
  return (avg: total / texts.length, histogram: histogram);
}

/// Ranks participants by average message length, descending. Participants
/// under [kMinLengthSamples] texted messages are dropped rather than shown
/// with a misleadingly noisy average — a single 200-character message
/// shouldn't crown someone "sends the longest".
List<ParticipantLengthStats> _computeLengthLeaderboard(Map<int, List<int>> lengthsByParticipant) {
  final result = <ParticipantLengthStats>[];
  for (final entry in lengthsByParticipant.entries) {
    if (entry.value.length < kMinLengthSamples) continue;
    final total = entry.value.fold<int>(0, (a, b) => a + b);
    result.add(ParticipantLengthStats(
      participantId: entry.key,
      avgLength: total / entry.value.length,
      messageCount: entry.value.length,
    ));
  }
  result.sort((a, b) => b.avgLength.compareTo(a.avgLength));
  return result;
}

/// Normalizes raw reaction rows into net given/received-by-type maps plus a
/// taken-back count. Shared by [computeContent] and [computeReactionMatrix]
/// so both apply the exact same `-`-prefix and sticker filtering.
///
/// A reaction added then removed produces two rows; the net (adds minus
/// removals) is what's reported per type, never a negative count.
({Map<String, int> given, Map<String, int> received, int takenBack}) _normalizeReactions(
  List<({String type, bool fromMe})> reactions,
) {
  final addedGiven = <String, int>{};
  final addedReceived = <String, int>{};
  final removedGiven = <String, int>{};
  final removedReceived = <String, int>{};

  for (final r in reactions) {
    final isRemoval = r.type.startsWith('-');
    final normalized = r.type.replaceAll('-', '');
    if (!ReactionTypes.toList().contains(normalized)) continue; // stickers, etc.
    final bucket = r.fromMe ? (isRemoval ? removedGiven : addedGiven) : (isRemoval ? removedReceived : addedReceived);
    bucket.update(normalized, (v) => v + 1, ifAbsent: () => 1);
  }

  final given = <String, int>{
    for (final t in ReactionTypes.toList())
      t: ((addedGiven[t] ?? 0) - (removedGiven[t] ?? 0)).clamp(0, 1 << 31).toInt(),
  };
  final received = <String, int>{
    for (final t in ReactionTypes.toList())
      t: ((addedReceived[t] ?? 0) - (removedReceived[t] ?? 0)).clamp(0, 1 << 31).toInt(),
  };
  final takenBack = removedGiven.values.fold<int>(0, (a, b) => a + b) +
      removedReceived.values.fold<int>(0, (a, b) => a + b);

  return (given: given, received: received, takenBack: takenBack);
}

ContentStats computeContent({
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
  final mineLength = _lengthStats(myTexts);
  final theirsLength = _lengthStats(theirTexts);
  final lengthLeaderboard = _computeLengthLeaderboard(lengthsByParticipant);

  final emojiMine = _countEmoji(myTexts);
  final emojiTheirs = _countEmoji(theirTexts);
  final emojiKeys = {...emojiMine.keys, ...emojiTheirs.keys};
  final topEmoji = emojiKeys.map((e) => EmojiCount(e, emojiMine[e] ?? 0, emojiTheirs[e] ?? 0)).toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  final wordCounts = _countWords([...myTexts, ...theirTexts]);
  final topWords = wordCounts.entries
      .where((e) => e.value >= 2)
      .map((e) => WordCount(e.key, e.value))
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  final reactionSummary = _normalizeReactions(reactions);

  final mimeCounts = <String, int>{};
  for (final m in attachmentMimeTypes) {
    final top = m.split('/').first;
    mimeCounts.update(top.isEmpty ? 'other' : top, (v) => v + 1, ifAbsent: () => 1);
  }

  final effectCounts = <String, int>{};
  for (final id in expressiveSendStyleIds) {
    effectCounts.update(id, (v) => v + 1, ifAbsent: () => 1);
  }

  return ContentStats(
    textCoverage: textCoverage,
    windowed: windowed,
    analyzedMessageCount: myTexts.length + theirTexts.length,
    avgLengthMine: mineLength.avg,
    avgLengthTheirs: theirsLength.avg,
    lengthHistogramMine: mineLength.histogram,
    lengthHistogramTheirs: theirsLength.histogram,
    messageLengthLeaderboard: lengthLeaderboard,
    topEmoji: topEmoji.take(20).toList(),
    topWords: topWords.take(30).toList(),
    reactionsGivenByType: reactionSummary.given,
    reactionsReceivedByType: reactionSummary.received,
    reactionsTakenBack: reactionSummary.takenBack,
    attachmentMimeCounts: mimeCounts,
    effectIdCounts: effectCounts,
    editedCount: editedCount,
    unsentCount: unsentCount,
    audioSent: audioSent,
    audioReceived: audioReceived,
    audioPlayedRatio: audioPlayedRatio,
  );
}

// ── Members — reaction matrix (Task 12) ────────────────────────────────────

/// Builds the reactor×target matrix from raw rows + a guid→sender map. Rows
/// whose target guid isn't in [guidToSender] (message outside the window, or
/// deleted) are dropped rather than guessed at.
ReactionMatrixStats computeReactionMatrix({
  required List<ReactionMatrixRow> reactionRows,
  required Map<String, int> guidToSender,
  required List<int> participantIds,
  required int windowMonths,
}) {
  final index = {for (var i = 0; i < participantIds.length; i++) participantIds[i]: i};
  final matrix = List.generate(participantIds.length, (_) => List<int>.filled(participantIds.length, 0));

  for (final row in reactionRows) {
    final isRemoval = row.type.startsWith('-');
    if (isRemoval) continue; // matrix shows current state, not history of edits
    final normalized = row.type.replaceAll('-', '');
    if (!ReactionTypes.toList().contains(normalized)) continue; // stickers, etc.

    final targetSender = guidToSender[row.targetGuid];
    if (targetSender == null) continue;
    final r = index[row.reactorId];
    final t = index[targetSender];
    if (r == null || t == null) continue;
    matrix[r][t]++;
  }

  return ReactionMatrixStats(participantIds: participantIds, matrix: matrix, windowMonths: windowMonths);
}
