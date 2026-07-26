import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/chat_stats_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/charts/bar_chart.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/charts/donut_chart.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/charts/line_chart.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/legend_grid.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/participant_bar.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/section_skeleton.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/stat_tile.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The conversation-engagement tab — response times, openers/enders,
/// double-texting, balance drift, longest silence, and (1:1 only) left on
/// read. See `docs/feature-planning/chat-stats/tasks/10-engagement-tab-ui.md`.
class ChatStatsEngagementTab extends StatefulWidget {
  const ChatStatsEngagementTab({super.key, required this.controller});

  final ChatStatsController controller;

  @override
  State<ChatStatsEngagementTab> createState() => _ChatStatsEngagementTabState();
}

class _ChatStatsEngagementTabState extends State<ChatStatsEngagementTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.controller.ensureSection(StatsStage.computingEngagement);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() {
      final engagement = widget.controller.stats.value?.engagement;
      final error = widget.controller.error.value;
      // See the matching comment in chat_stats_overview_tab.dart — this
      // registers the Obx dependency so the tab rebuilds once participant
      // names/avatars resolve asynchronously, instead of showing "Unknown".
      // ignore: unused_local_variable
      final participantCount = widget.controller.participants.length;

      if (engagement == null && error != null) {
        return _ErrorState(onRetry: () => widget.controller.ensureSection(StatsStage.computingEngagement, force: true));
      }

      if (engagement == null) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 36.0),
          children: const [SectionSkeleton(height: 220.0), SizedBox(height: 12.0), SectionSkeleton(height: 220.0)],
        );
      }

      final totalMessages = engagement.sessionsStarted.values.fold<int>(0, (a, b) => a + b);
      if (totalMessages == 0) {
        return Center(
          child: Text(
            "No messages to analyze yet",
            style: context.theme.textTheme.bodyLarge?.copyWith(color: context.theme.colorScheme.outline),
          ),
        );
      }

      return _EngagementContent(controller: widget.controller, engagement: engagement);
    });
  }
}

class _EngagementContent extends StatelessWidget {
  const _EngagementContent({required this.controller, required this.engagement});

  final ChatStatsController controller;
  final EngagementStats engagement;

  bool get isGroup => controller.isGroup;

  int? get _theirId => controller.participants.keys.firstWhereOrNull((id) => id != kMeParticipantId);

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 36.0),
      children: [
        _ResponseTimeSection(controller: controller, engagement: engagement, theirId: _theirId),
        const SizedBox(height: 28.0),
        Text("Who Texts First", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _sharesDonut(context, engagement.sessionsStarted),
        const SizedBox(height: 28.0),
        Text("Who Ends Conversations", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _sharesDonut(context, engagement.sessionsEnded),
        const SizedBox(height: 28.0),
        Text("Double-Texting", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _DoubleTextSection(controller: controller, engagement: engagement, theirId: _theirId),
        const SizedBox(height: 28.0),
        _BalanceDriftSection(controller: controller, engagement: engagement),
        const SizedBox(height: 28.0),
        StatTileGrid(tiles: [
          StatTile(
            value: engagement.longestSilenceMillis == null ? "—" : formatEngagementDuration(engagement.longestSilenceMillis!),
            label: "Longest Silence",
            caption: engagement.longestSilenceStartMillis == null
                ? null
                : "started ${buildFullDate(DateTime.fromMillisecondsSinceEpoch(engagement.longestSilenceStartMillis!), includeTime: false)}",
          ),
          if (!isGroup) _leftOnReadTile(context),
        ]),
        const SizedBox(height: 12.0),
      ],
    );
  }

  Widget _sharesDonut(BuildContext context, Map<int, int> counts) {
    final entries = counts.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return Text(
        "Not enough data yet.",
        style: context.theme.textTheme.bodyMedium?.copyWith(color: context.theme.colorScheme.outline),
      );
    }
    return DonutChart(
      slices: [
        for (final e in entries)
          DonutSlice(
            label: controller.participants[e.key]?.displayName ?? (e.key == kMeParticipantId ? "You" : "Unknown"),
            value: e.value.toDouble(),
            color: participantColor(context, e.key, controller.participants),
          ),
      ],
    );
  }

  StatTile _leftOnReadTile(BuildContext context) {
    final coverage = engagement.readReceiptCoverage;
    if (coverage == null || coverage < kMinReadReceiptCoverage) {
      return const StatTile(value: "—", label: "Left on Read", caption: "Read receipts aren't available");
    }
    const hours = kSessionGapMillis ~/ (60 * 60 * 1000);
    return StatTile(
      value: "${engagement.leftOnReadCount ?? 0}",
      label: "Left on Read",
      caption: "Read w/o a reply within ${hours}h",
    );
  }
}

class _ResponseTimeSection extends StatelessWidget {
  const _ResponseTimeSection({required this.controller, required this.engagement, required this.theirId});

  final ChatStatsController controller;
  final EngagementStats engagement;
  final int? theirId;

  bool get isGroup => controller.isGroup;

  @override
  Widget build(BuildContext context) {
    final mine = engagement.responseTimes[kMeParticipantId] ?? ResponseTimeStats.empty;
    final hasEnoughData = engagement.responseTimes.values.any((v) => v.sampleCount >= kMinResponseSamples);

    if (!hasEnoughData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Response Time", style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 8.0),
          Text(
            "Not enough back-and-forth to measure response times yet.",
            style: context.theme.textTheme.bodyMedium?.copyWith(color: context.theme.colorScheme.outline),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Response Time", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        if (!isGroup) ...[
          StatTileGrid(tiles: [
            StatTile(value: mine.medianMillis == null ? "—" : formatEngagementDuration(mine.medianMillis!), label: "Your Median"),
            StatTile(
              value: mine.p90Millis == null ? "—" : formatEngagementDuration(mine.p90Millis!),
              label: "Your p90",
              caption: "90% of replies are faster than this",
            ),
            if (theirId != null) ...[
              StatTile(
                value: engagement.responseTimes[theirId]?.medianMillis == null
                    ? "—"
                    : formatEngagementDuration(engagement.responseTimes[theirId]!.medianMillis!),
                label: "${controller.participants[theirId]?.displayName ?? 'Their'} Median",
              ),
              StatTile(
                value: engagement.responseTimes[theirId]?.p90Millis == null
                    ? "—"
                    : formatEngagementDuration(engagement.responseTimes[theirId]!.p90Millis!),
                label: "${controller.participants[theirId]?.displayName ?? 'Their'} p90",
                caption: "90% of replies are faster than this",
              ),
            ],
          ]),
          const SizedBox(height: 16.0),
          _histogram(context, mine, theirId != null ? engagement.responseTimes[theirId] : null, "You", "Them"),
        ] else ...[
          StatTileGrid(tiles: [
            StatTile(value: mine.medianMillis == null ? "—" : formatEngagementDuration(mine.medianMillis!), label: "Your Median"),
            StatTile(
              value: mine.p90Millis == null ? "—" : formatEngagementDuration(mine.p90Millis!),
              label: "Your p90",
              caption: "90% of replies are faster than this",
            ),
          ]),
          const SizedBox(height: 16.0),
          Text(
            "Typical time to join in",
            style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.outline),
          ),
          const SizedBox(height: 8.0),
          _histogram(context, mine, _groupAggregate(), "You", "Group", showYAxis: true),
          const SizedBox(height: 16.0),
          _RankedDurationList(
            title: "Fastest to Reply",
            controller: controller,
            entries: {
              for (final entry in engagement.responseTimes.entries)
                if (entry.key != kMeParticipantId && entry.value.sampleCount >= kMinResponseSamples) entry.key: entry.value.medianMillis!,
            },
            ascending: true,
          ),
        ],
      ],
    );
  }

  ResponseTimeStats? _groupAggregate() {
    final histogram = List<int>.filled(kResponseBucketLabels.length, 0);
    int sampleCount = 0;
    for (final entry in engagement.responseTimes.entries) {
      if (entry.key == kMeParticipantId) continue;
      for (var i = 0; i < histogram.length; i++) {
        histogram[i] += entry.value.histogram[i];
      }
      sampleCount += entry.value.sampleCount;
    }
    if (sampleCount == 0) return null;
    return ResponseTimeStats(histogram: histogram, sampleCount: sampleCount);
  }

  Widget _histogram(
    BuildContext context,
    ResponseTimeStats mine,
    ResponseTimeStats? other,
    String mineLabel,
    String otherLabel, {
    bool showYAxis = false,
  }) {
    final mineColor = context.theme.colorScheme.primary;
    final otherColor = context.theme.colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14.0,
          children: [
            _swatch(context, mineColor, mineLabel),
            if (other != null) _swatch(context, otherColor, otherLabel),
          ],
        ),
        const SizedBox(height: 8.0),
        StatBarChart(
          height: 160.0,
          showYAxis: showYAxis,
          groups: [
            for (var i = 0; i < kResponseBucketLabels.length; i++)
              BarGroupSpec(
                label: kResponseBucketLabels[i],
                bars: [
                  BarValueSpec(value: mine.histogram[i].toDouble(), color: mineColor),
                  if (other != null) BarValueSpec(value: other.histogram[i].toDouble(), color: otherColor),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _swatch(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10.0, height: 10.0, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5.0),
        Text(label, style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.outline)),
      ],
    );
  }
}

class _DoubleTextSection extends StatelessWidget {
  const _DoubleTextSection({required this.controller, required this.engagement, required this.theirId});

  final ChatStatsController controller;
  final EngagementStats engagement;
  final int? theirId;

  @override
  Widget build(BuildContext context) {
    if (!controller.isGroup) {
      return StatTileGrid(tiles: [
        StatTile(value: "${engagement.doubleTexts[kMeParticipantId] ?? 0}", label: "You"),
        StatTile(
          value: "${theirId == null ? 0 : engagement.doubleTexts[theirId] ?? 0}",
          label: controller.participants[theirId]?.displayName ?? "Them",
        ),
      ]);
    }
    return _RankedDurationList(
      title: null,
      controller: controller,
      entries: {for (final e in engagement.doubleTexts.entries) if (e.value > 0) e.key: e.value},
      ascending: false,
      formatValue: (v) => "$v",
    );
  }
}

class _BalanceDriftSection extends StatelessWidget {
  const _BalanceDriftSection({required this.controller, required this.engagement});

  final ChatStatsController controller;
  final EngagementStats engagement;

  @override
  Widget build(BuildContext context) {
    final points = engagement.balanceDrift;
    if (points.length < 4) return const SizedBox.shrink();

    final ids = <int>{};
    for (final bucket in points) {
      ids.addAll(bucket.byParticipant.keys);
    }

    if (!controller.isGroup) {
      final theirId = ids.firstWhereOrNull((id) => id != kMeParticipantId);
      final values = [
        for (final b in points) b.total == 0 ? 50.0 : (b.byParticipant[kMeParticipantId] ?? 0) / b.total * 100,
      ];
      final secondaryColor =
          theirId == null ? context.theme.colorScheme.outline : participantColor(context, theirId, controller.participants);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Balance Drift", style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 4.0),
          Text(
            "Your share of messages over time",
            style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.outline),
          ),
          const SizedBox(height: 10.0),
          ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: StatLineChart(
              series: [ChartSeries(label: "You", color: context.theme.colorScheme.primary, values: values)],
              mode: LineChartMode.referenceSplit,
              minY: 0,
              maxY: 100,
              referenceY: 50,
              secondaryColor: secondaryColor,
            ),
          ),
          const SizedBox(height: 8.0),
          LegendGrid(items: [
            (label: "You", color: context.theme.colorScheme.primary),
            (label: controller.participants[theirId]?.displayName ?? "Them", color: secondaryColor),
          ]),
        ],
      );
    }

    final totals = <int, int>{};
    for (final bucket in points) {
      for (final e in bucket.byParticipant.entries) {
        totals.update(e.key, (v) => v + e.value, ifAbsent: () => e.value);
      }
    }
    const cap = 5; // + me + others
    final ranked = totals.keys.where((id) => id != kMeParticipantId).toList()..sort((a, b) => totals[b]!.compareTo(totals[a]!));
    final top = ranked.take(cap).toList();
    final rest = ranked.skip(cap).toList();
    final orderedIds = [if (totals.containsKey(kMeParticipantId)) kMeParticipantId, ...top];

    final series = [
      for (final id in orderedIds)
        ChartSeries(
          label: controller.participants[id]?.displayName ?? "Unknown",
          color: participantColor(context, id, controller.participants),
          values: [for (final b in points) b.total == 0 ? 0.0 : (b.byParticipant[id] ?? 0) / b.total * 100],
        ),
    ];
    if (rest.isNotEmpty) {
      series.add(ChartSeries(
        label: "Others",
        color: context.theme.colorScheme.outlineVariant,
        values: [for (final b in points) b.total == 0 ? 0.0 : rest.fold<double>(0, (a, id) => a + (b.byParticipant[id] ?? 0)) / b.total * 100],
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Balance Drift", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: StatLineChart(
            series: series,
            mode: LineChartMode.stackedArea,
            minY: 0,
            maxY: 100,
            referenceY: 100 / (orderedIds.isEmpty ? 1 : orderedIds.length),
          ),
        ),
        const SizedBox(height: 8.0),
        LegendGrid(items: [for (final s in series) (label: s.label, color: s.color)]),
      ],
    );
  }
}


/// Ranked list of per-participant values with avatars — reads better than an
/// N-way chart for "fastest to reply" / double-text counts in a group.
class _RankedDurationList extends StatefulWidget {
  const _RankedDurationList({
    required this.title,
    required this.controller,
    required this.entries,
    required this.ascending,
    this.formatValue,
  });

  final String? title;
  final ChatStatsController controller;
  final Map<int, int> entries; // participantId -> millis (duration) or raw count
  final bool ascending;
  final String Function(int value)? formatValue;

  @override
  State<_RankedDurationList> createState() => _RankedDurationListState();
}

class _RankedDurationListState extends State<_RankedDurationList> {
  static const int _cap = 8;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.entries.entries.toList()
      ..sort((a, b) => widget.ascending ? a.value.compareTo(b.value) : b.value.compareTo(a.value));
    if (rows.isEmpty) {
      return Text(
        "Not enough data yet.",
        style: context.theme.textTheme.bodyMedium?.copyWith(color: context.theme.colorScheme.outline),
      );
    }
    final visible = _showAll ? rows : rows.take(_cap).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(widget.title!, style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 8.0),
        ],
        for (var i = 0; i < visible.length; i++)
          _RankedRow(
            rank: i + 1,
            participantId: visible[i].key,
            valueLabel: widget.formatValue?.call(visible[i].value) ?? formatEngagementDuration(visible[i].value),
            controller: widget.controller,
          ),
        if (!_showAll && rows.length > _cap)
          TextButton(onPressed: () => setState(() => _showAll = true), child: Text("Show all (${rows.length})")),
      ],
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({required this.rank, required this.participantId, required this.valueLabel, required this.controller});

  final int rank;
  final int participantId;
  final String valueLabel;
  final ChatStatsController controller;

  @override
  Widget build(BuildContext context) {
    final info = controller.participants[participantId];
    final isMe = participantId == kMeParticipantId;
    final handle = isMe ? null : Database.handles.get(participantId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(width: 20.0, child: Text("$rank", style: context.theme.textTheme.labelSmall)),
          const SizedBox(width: 6.0),
          ContactAvatarWidget(handle: handle, size: 28, editable: false),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              info?.displayName ?? "Unknown",
              style: context.theme.textTheme.bodyMedium?.copyWith(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(valueLabel, style: context.theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Compact human duration for response times / silences ("42s", "6m", "3h", "2d").
String formatEngagementDuration(int millis) {
  final d = Duration(milliseconds: millis);
  if (d.inMinutes < 1) return "${d.inSeconds}s";
  if (d.inHours < 1) return "${d.inMinutes}m";
  if (d.inDays < 1) return "${d.inHours}h";
  return "${d.inDays}d";
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Could not load these stats.",
            style: context.theme.textTheme.bodyLarge?.copyWith(color: context.theme.colorScheme.outline),
          ),
          const SizedBox(height: 10.0),
          TextButton(onPressed: onRetry, child: const Text("Retry")),
        ],
      ),
    );
  }
}
