import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/chat_stats_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/charts/sparkline.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/participant_bar.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/section_skeleton.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/stat_tile.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ChatStatsOverviewTab extends StatefulWidget {
  const ChatStatsOverviewTab({super.key, required this.controller});

  final ChatStatsController controller;

  @override
  State<ChatStatsOverviewTab> createState() => _ChatStatsOverviewTabState();
}

class _ChatStatsOverviewTabState extends State<ChatStatsOverviewTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.controller.ensureSection(StatsStage.computingOverview);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() {
      final overview = widget.controller.stats.value?.overview;
      final error = widget.controller.error.value;
      // Participant names/avatars resolve asynchronously after the (fast)
      // overview compute and are read as plain map lookups several widgets
      // down — reading `.length` here (rather than deep in a StatelessWidget's
      // own build, which runs outside this Obx's tracked zone) registers the
      // dependency, so this Obx rebuilds — and the leaderboard/balance bar
      // re-read fresh names — once resolution finishes, instead of showing
      // "Unknown" forever.
      // ignore: unused_local_variable
      final participantCount = widget.controller.participants.length;

      if (overview == null && error != null) {
        return _ErrorState(onRetry: () => widget.controller.ensureSection(StatsStage.computingOverview, force: true));
      }

      if (overview == null) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 36.0),
          children: const [SectionSkeleton(height: 220.0)],
        );
      }

      if (overview.total == 0) {
        return Center(
          child: Text(
            "No messages to analyze yet",
            style: context.theme.textTheme.bodyLarge?.copyWith(color: context.theme.colorScheme.outline),
          ),
        );
      }

      return _OverviewContent(controller: widget.controller, overview: overview);
    });
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({required this.controller, required this.overview});

  final ChatStatsController controller;
  final OverviewStats overview;

  @override
  Widget build(BuildContext context) {
    final activity = controller.stats.value?.activity;
    // Already scoped to the selected timeframe at the query level (see
    // `ChatStatsQueries.realMessages`'s `sinceMillis`) — no further slicing
    // needed here the way a fixed "last 90 days" cap used to require.
    final dailySeries = activity?.dailySeries ?? const <TimeBucket>[];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 36.0),
      children: [
        Text(controller.timeframe.value.longLabel, style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        activity == null
            ? const SectionSkeleton(height: 60.0)
            : Sparkline(
                buckets: dailySeries,
                xLabelBuilder: (i) {
                  if (i < 0 || i >= dailySeries.length) return null;
                  final step = (dailySeries.length / 5).ceil().clamp(1, dailySeries.length);
                  if (i % step != 0) return null;
                  return DateFormat.Md().format(DateTime.fromMillisecondsSinceEpoch(dailySeries[i].startMillis));
                },
              ),
        const SizedBox(height: 24.0),
        StatTileGrid(tiles: [
          StatTile(value: overview.total.formatStatCount(), label: "Total Messages"),
          StatTile(value: overview.sent.formatStatCount(), label: "Sent"),
          StatTile(value: overview.received.formatStatCount(), label: "Received"),
          StatTile(value: overview.averagePerDay.toStringAsFixed(1), label: "Avg / Day"),
          StatTile(value: "${overview.currentStreak}", label: "Current Streak", caption: "days"),
          StatTile(value: "${overview.longestStreak}", label: "Longest Streak", caption: "days"),
          StatTile(value: overview.attachments.formatStatCount(), label: "Attachments"),
        ]),
        if (overview.unattributedCount > 0) ...[
          const SizedBox(height: 8.0),
          Text(
            "${overview.unattributedCount.formatStatCount()} messages from an unresolved sender aren't reflected in "
            "the balance bar or leaderboard.",
            style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.outline),
          ),
        ],
        const SizedBox(height: 20.0),
        Text("Balance", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        ParticipantBar(leaderboard: overview.leaderboard, participants: controller.participants),
        if (controller.isGroup) ...[
          const SizedBox(height: 24.0),
          Text("Leaderboard", style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 10.0),
          _Leaderboard(leaderboard: overview.leaderboard, participants: controller.participants, chat: controller.chat),
        ],
        const SizedBox(height: 12.0),
      ],
    );
  }
}

class _Leaderboard extends StatefulWidget {
  const _Leaderboard({required this.leaderboard, required this.participants, required this.chat});

  final List<ParticipantCount> leaderboard;
  final Map<int, ParticipantInfo> participants;
  final Chat chat;

  @override
  State<_Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<_Leaderboard> {
  static const int _cap = 10;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.leaderboard.where((e) => e.participantId != kMeParticipantId).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final me = widget.leaderboard.where((e) => e.participantId == kMeParticipantId).firstOrNull;
    final maxCount = rows.isEmpty ? 1 : rows.first.count;
    final visible = _showAll ? rows : rows.take(_cap).toList();
    final currentHandleIds = widget.chat.handles.map((h) => h.id).whereType<int>().toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (me != null) _LeaderboardRow(count: me, participants: widget.participants, maxCount: maxCount, isDeparted: false),
        for (final row in visible)
          _LeaderboardRow(
            count: row,
            participants: widget.participants,
            maxCount: maxCount,
            isDeparted: !currentHandleIds.contains(row.participantId),
          ),
        if (!_showAll && rows.length > _cap)
          TextButton(
            onPressed: () => setState(() => _showAll = true),
            child: Text("Show all (${rows.length})"),
          ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.count,
    required this.participants,
    required this.maxCount,
    required this.isDeparted,
  });

  final ParticipantCount count;
  final Map<int, ParticipantInfo> participants;
  final int maxCount;
  final bool isDeparted;

  @override
  Widget build(BuildContext context) {
    final info = participants[count.participantId];
    final isMe = count.participantId == kMeParticipantId;
    final handle = isMe ? null : Database.handles.get(count.participantId);
    final share = maxCount == 0 ? 0.0 : count.count / maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          ContactAvatarWidget(handle: handle, size: 32, editable: false),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        info?.displayName ?? "Unknown",
                        style: context.theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isDeparted) ...[
                      const SizedBox(width: 6.0),
                      Text(
                        "left",
                        style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.outline),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4.0),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 6.0,
                    backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                    color: participantColor(context, count.participantId, participants),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10.0),
          Text(count.count.formatStatCount(), style: context.theme.textTheme.bodyMedium),
        ],
      ),
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
