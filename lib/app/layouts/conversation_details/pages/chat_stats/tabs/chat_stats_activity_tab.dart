import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/chat_stats_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/charts/bar_chart.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/charts/line_chart.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/heatmap_grid.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/participant_bar.dart';
import 'package:bluebubbles/app/components/charts/section_skeleton.dart';
import 'package:bluebubbles/app/components/charts/stat_tile.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_computer.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

const _kWeekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

/// Cap on stacked-area series in the group volume chart — a 20-series stack is
/// unreadable, so the rest collapse into a single "Others" band.
const int _kMaxVolumeSeries = 6;

/// The time-pattern tab — weekday×hour heatmap, hour/day-of-week bars, the
/// calendar heatmap, and a bucketed volume chart. See
/// `docs/feature-planning/chat-stats/tasks/09-activity-tab-ui.md`.
class ChatStatsActivityTab extends StatefulWidget {
  const ChatStatsActivityTab({super.key, required this.controller});

  final ChatStatsController controller;

  @override
  State<ChatStatsActivityTab> createState() => _ChatStatsActivityTabState();
}

class _ChatStatsActivityTabState extends State<ChatStatsActivityTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _totalOnly = false;

  @override
  void initState() {
    super.initState();
    widget.controller.ensureSection(StatsStage.computingActivity);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() {
      final activity = widget.controller.stats.value?.activity;
      final error = widget.controller.error.value;
      // See the matching comment in chat_stats_overview_tab.dart — this
      // registers the Obx dependency so the tab rebuilds once participant
      // names/avatars resolve asynchronously, instead of showing "Unknown".
      // ignore: unused_local_variable
      final participantCount = widget.controller.participants.length;

      if (activity == null && error != null) {
        return _ErrorState(onRetry: () => widget.controller.ensureSection(StatsStage.computingActivity, force: true));
      }

      if (activity == null) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 36.0),
          children: const [SectionSkeleton(height: 220.0), SizedBox(height: 12.0), SectionSkeleton(height: 220.0)],
        );
      }

      if (activity.dailySeries.isEmpty) {
        return Center(
          child: Text(
            "No messages to analyze yet",
            style: context.theme.textTheme.bodyLarge?.copyWith(color: context.theme.colorScheme.outline),
          ),
        );
      }

      return _ActivityContent(
        controller: widget.controller,
        activity: activity,
        totalOnly: _totalOnly,
        onBucketChanged: (size) => widget.controller.bucketSize.value = size,
        onTotalOnlyChanged: (value) => setState(() => _totalOnly = value),
      );
    });
  }
}

class _ActivityContent extends StatelessWidget {
  const _ActivityContent({
    required this.controller,
    required this.activity,
    required this.totalOnly,
    required this.onBucketChanged,
    required this.onTotalOnlyChanged,
  });

  final ChatStatsController controller;
  final ActivityStats activity;
  final bool totalOnly;
  final void Function(StatsBucketSize size) onBucketChanged;
  final void Function(bool value) onTotalOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 36.0),
      children: [
        StatTileGrid(tiles: [
          StatTile(value: _formatHour(activity.peakHour), label: "Peak Hour"),
          StatTile(value: "${(activity.nightOwlRatio * 100).round()}%", label: "Night Owl", caption: "12–4am"),
          StatTile(
            value: activity.busiestDayMillis == null
                ? "—"
                : buildFullDate(DateTime.fromMillisecondsSinceEpoch(activity.busiestDayMillis!), includeTime: false),
            label: "Busiest Day",
            caption: "${activity.busiestDayCount} messages",
          ),
        ]),
        const SizedBox(height: 24.0),
        _VolumeSection(
          controller: controller,
          activity: activity,
          totalOnly: totalOnly,
          onBucketChanged: onBucketChanged,
          onTotalOnlyChanged: onTotalOnlyChanged,
        ),
        const SizedBox(height: 28.0),
        Text("Weekday x Hour", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _WeekdayHourHeatmap(activity: activity),
        const SizedBox(height: 28.0),
        Text("Hour of Day", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        StatBarChart(
          labelEvery: 3,
          groups: [
            for (var h = 0; h < 24; h++)
              BarGroupSpec(
                label: _formatHour(h),
                bars: [BarValueSpec(value: activity.byHour[h].toDouble(), color: context.theme.colorScheme.primary)],
              ),
          ],
        ),
        const SizedBox(height: 28.0),
        Text("Day of Week", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        StatBarChart(
          groups: [
            for (var d = 0; d < 7; d++)
              BarGroupSpec(
                label: _kWeekdayLabels[d],
                bars: [BarValueSpec(value: activity.byWeekday[d].toDouble(), color: context.theme.colorScheme.primary)],
              ),
          ],
        ),
        const SizedBox(height: 28.0),
        Text("Calendar", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _CalendarHeatmap(activity: activity),
        const SizedBox(height: 12.0),
      ],
    );
  }

  static String _formatHour(int hour) {
    final dt = DateTime(2000, 1, 1, hour);
    return SettingsSvc.settings.use24HrFormat.value ? DateFormat.Hm().format(dt) : DateFormat.j().format(dt);
  }
}

class _VolumeSection extends StatelessWidget {
  const _VolumeSection({
    required this.controller,
    required this.activity,
    required this.totalOnly,
    required this.onBucketChanged,
    required this.onTotalOnlyChanged,
  });

  final ChatStatsController controller;
  final ActivityStats activity;
  final bool totalOnly;
  final void Function(StatsBucketSize size) onBucketChanged;
  final void Function(bool value) onTotalOnlyChanged;

  @override
  Widget build(BuildContext context) {
    // Wrapped in its own Obx: `bucketSize` is a different Rx than the outer
    // tab's `stats`, so switching a chip must re-run this closure directly
    // rather than rely on the outer Obx picking it up.
    return Obx(() => _build(context));
  }

  Widget _build(BuildContext context) {
    final bucketSize = controller.bucketSize.value;
    // Tracked alongside `bucketSize` in this same local `Obx` — selecting a
    // comparison target only rebuilds this chart, not the whole Activity tab.
    final comparisonId = controller.comparisonParticipantId.value;

    // The window itself comes from the page-level timeframe selector —
    // `activity.dailySeries` is already scoped to it (see `ChatStatsQueries`'s
    // `sinceMillis`) — this only controls re-bucketing that already-windowed
    // series to a coarser granularity.
    final buckets = rebucket(activity.dailySeries, bucketSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Volume Over Time", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 6.0,
          children: [
            _Chip(label: "Day", selected: bucketSize == StatsBucketSize.day, onTap: () => onBucketChanged(StatsBucketSize.day)),
            _Chip(label: "Week", selected: bucketSize == StatsBucketSize.week, onTap: () => onBucketChanged(StatsBucketSize.week)),
            _Chip(label: "Month", selected: bucketSize == StatsBucketSize.month, onTap: () => onBucketChanged(StatsBucketSize.month)),
            if (controller.isGroup && comparisonId == null) ...[
              const SizedBox(width: 12.0),
              _Chip(label: "Total only", selected: totalOnly, onTap: () => onTotalOnlyChanged(!totalOnly)),
            ],
          ],
        ),
        const SizedBox(height: 12.0),
        if (buckets.isEmpty)
          const SizedBox(height: 180.0)
        else
          StatLineChart(
            height: 200.0,
            series: _buildSeries(context, buckets, comparisonId),
            mode: controller.isGroup && comparisonId == null && !totalOnly ? LineChartMode.stackedArea : LineChartMode.lines,
            showYAxis: true,
            xLabelBuilder: (i) {
              if (i < 0 || i >= buckets.length) return null;
              final step = (buckets.length / 6).ceil().clamp(1, buckets.length);
              if (i % step != 0) return null;
              return _bucketLabel(buckets[i].startMillis, bucketSize);
            },
          ),
      ],
    );
  }

  List<ChartSeries> _buildSeries(BuildContext context, List<TimeBucket> buckets, int? comparisonId) {
    if (!controller.isGroup) {
      final theirId = controller.participants.keys.firstWhereOrNull((id) => id != kMeParticipantId);
      return [
        ChartSeries(
          label: "You",
          color: context.theme.colorScheme.primary,
          values: [for (final b in buckets) b.sent.toDouble()],
        ),
        ChartSeries(
          label: controller.participants[theirId]?.displayName ?? "Them",
          color: theirId == null
              ? context.theme.colorScheme.outline
              : participantColor(context, theirId, controller.participants),
          values: [for (final b in buckets) b.received.toDouble()],
        ),
      ];
    }

    if (comparisonId != null) {
      // A specific group member is selected: show the same two-series shape
      // as a 1:1 chat, scoped to just "you" and that person — not diluted by
      // the rest of the group.
      return [
        ChartSeries(
          label: "You",
          color: context.theme.colorScheme.primary,
          values: [for (final b in buckets) (b.byParticipant[kMeParticipantId] ?? 0).toDouble()],
        ),
        ChartSeries(
          label: controller.participants[comparisonId]?.displayName ?? "Them",
          color: participantColor(context, comparisonId, controller.participants),
          values: [for (final b in buckets) (b.byParticipant[comparisonId] ?? 0).toDouble()],
        ),
      ];
    }

    if (totalOnly) {
      return [
        ChartSeries(
          label: "Total",
          color: context.theme.colorScheme.primary,
          values: [for (final b in buckets) b.total.toDouble()],
        ),
      ];
    }

    final totals = <int, int>{};
    for (final bucket in buckets) {
      for (final entry in bucket.byParticipant.entries) {
        totals.update(entry.key, (v) => v + entry.value, ifAbsent: () => entry.value);
      }
    }
    final ranked = totals.keys.where((id) => id != kMeParticipantId).toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
    final topOthers = ranked.take(_kMaxVolumeSeries - 1).toList();
    final rest = ranked.skip(_kMaxVolumeSeries - 1).toList();

    final orderedIds = [if (totals.containsKey(kMeParticipantId)) kMeParticipantId, ...topOthers];
    final series = [
      for (final id in orderedIds)
        ChartSeries(
          label: controller.participants[id]?.displayName ?? "Unknown",
          color: participantColor(context, id, controller.participants),
          values: [for (final b in buckets) (b.byParticipant[id] ?? 0).toDouble()],
        ),
    ];
    if (rest.isNotEmpty) {
      series.add(ChartSeries(
        label: "Others",
        color: context.theme.colorScheme.outlineVariant,
        values: [for (final b in buckets) rest.fold<double>(0, (a, id) => a + (b.byParticipant[id] ?? 0))],
      ));
    }
    return series;
  }

  static String _bucketLabel(int millis, StatsBucketSize size) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    return switch (size) {
      StatsBucketSize.day => DateFormat.Md().format(date),
      StatsBucketSize.week => DateFormat.Md().format(date),
      StatsBucketSize.month => DateFormat.MMM().format(date),
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12.0)),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _WeekdayHourHeatmap extends StatelessWidget {
  const _WeekdayHourHeatmap({required this.activity});

  final ActivityStats activity;

  @override
  Widget build(BuildContext context) {
    final maxValue = activity.weekdayHourGrid.expand((row) => row).fold<int>(0, (a, b) => b > a ? b : a);
    return HeatmapGrid(
      values: activity.weekdayHourGrid,
      maxValue: maxValue,
      rowLabels: _kWeekdayLabels,
      colLabels: [for (var h = 0; h < 24; h++) h % 3 == 0 ? _shortHour(h) : null],
      cellLabel: (row, col, value) => "${_kWeekdayLabels[row]} ${_shortHour(col)} · $value message${value == 1 ? '' : 's'}",
    );
  }

  static String _shortHour(int hour) {
    final dt = DateTime(2000, 1, 1, hour);
    return SettingsSvc.settings.use24HrFormat.value ? "${hour}h" : DateFormat('ha').format(dt).toLowerCase();
  }
}

class _CalendarHeatmap extends StatelessWidget {
  const _CalendarHeatmap({required this.activity});

  final ActivityStats activity;

  @override
  Widget build(BuildContext context) {
    final days = activity.dailySeries;
    if (days.isEmpty) return const SizedBox.shrink();

    final firstDay = DateTime.fromMillisecondsSinceEpoch(days.first.startMillis);
    final lastDay = DateTime.fromMillisecondsSinceEpoch(days.last.startMillis);
    final gridStart = firstDay.subtract(Duration(days: firstDay.weekday - 1)); // Monday-aligned
    final totalDays = lastDay.difference(gridStart).inDays + 1;
    final weeks = (totalDays / 7).ceil().clamp(1, 1000000);

    final values = List.generate(7, (_) => List<int>.filled(weeks, 0));
    for (final day in activity.byDay.entries) {
      final date = DateTime.fromMillisecondsSinceEpoch(day.key);
      final offset = date.difference(gridStart).inDays;
      if (offset < 0) continue;
      final col = offset ~/ 7;
      final row = date.weekday - 1;
      if (col < weeks) values[row][col] = day.value;
    }

    final colLabels = <String?>[];
    int? lastMonth;
    for (var c = 0; c < weeks; c++) {
      final colStart = gridStart.add(Duration(days: c * 7));
      if (colStart.month != lastMonth) {
        colLabels.add(DateFormat.MMM().format(colStart));
        lastMonth = colStart.month;
      } else {
        colLabels.add(null);
      }
    }

    final maxValue = values.expand((row) => row).fold<int>(0, (a, b) => b > a ? b : a);
    return HeatmapGrid(
      values: values,
      maxValue: maxValue,
      rowLabels: _kWeekdayLabels,
      colLabels: colLabels,
      cellSize: 12.0,
      scrollToEnd: true,
      cellLabel: (row, col, value) {
        final date = gridStart.add(Duration(days: col * 7 + row));
        return "${DateFormat.MMMd().format(date)} · $value message${value == 1 ? '' : 's'}";
      },
    );
  }
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
