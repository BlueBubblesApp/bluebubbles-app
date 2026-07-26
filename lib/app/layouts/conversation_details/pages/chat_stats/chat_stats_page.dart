import 'dart:async';

import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/chat_stats_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/tabs/chat_stats_content_tab.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/tabs/chat_stats_engagement_tab.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/tabs/chat_stats_overview_tab.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/tabs/chat_stats_activity_tab.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Tabbed shell for the Chat Stats page — staged progress bar, lazy per-tab
/// computation. See `docs/feature-planning/chat-stats/tasks/07-page-shell-and-entry-tile.md`.
class ChatStatsPage extends StatefulWidget {
  const ChatStatsPage({super.key, required this.chat});

  final Chat chat;

  @override
  State<ChatStatsPage> createState() => _ChatStatsPageState();
}

class _ChatStatsPageState extends State<ChatStatsPage> with SingleTickerProviderStateMixin, ThemeHelpers {
  static const _tabLabels = ["Overview", "Activity", "Engagement", "Content"];

  late final ChatStatsController controller;
  late final TabController tabController;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<ChatStatsController>(tag: widget.chat.guid)
        ? Get.find<ChatStatsController>(tag: widget.chat.guid)
        : Get.put(ChatStatsController(widget.chat), tag: widget.chat.guid);
    tabController = TabController(length: _tabLabels.length, vsync: this);
    // The refresh action targets whichever tab is visible — needs a rebuild
    // when that changes, which TabController doesn't trigger on its own.
    tabController.addListener(() {
      if (!tabController.indexIsChanging && mounted) setState(() {});
    });
    unawaited(controller.init());
  }

  @override
  void dispose() {
    tabController.dispose();
    Get.delete<ChatStatsController>(tag: widget.chat.guid);
    super.dispose();
  }

  StatsStage get _visibleStage => switch (tabController.index) {
        1 => StatsStage.computingActivity,
        2 => StatsStage.computingEngagement,
        3 => StatsStage.computingContent,
        _ => StatsStage.computingOverview,
      };

  @override
  Widget build(BuildContext context) {
    return BBScaffold(
      extendBodyBehindAppBar: false,
      appBar: BBAppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          // `BBAppBar` centers the title as a block on iOS (`centerTitle`
          // defaults to `context.iOS`), but a left-aligned two-line title
          // whose lines have very different widths (short "Stats" vs. a
          // potentially long chat name) still reads as off-center inside
          // that centered block. Centering the lines themselves fixes it;
          // Material/Samsung keep the conventional left alignment.
          crossAxisAlignment: iOS ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text("Stats", style: context.theme.textTheme.titleLarge),
            Text(
              widget.chat.getTitle(),
              style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.outline),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: buildBackButton(context),
        actions: [
          IconButton(
            icon: Icon(iOS ? CupertinoIcons.refresh : Icons.refresh),
            onPressed: () => controller.ensureSection(_visibleStage, force: true),
          ),
        ],
        bottom: TabBar(
          controller: tabController,
          isScrollable: true,
          tabs: _tabLabels.map((e) => Tab(text: e)).toList(),
        ),
      ),
      body: Column(
        children: [
          _TimeframeSelector(controller: controller),
          _ProgressBar(controller: controller),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                ChatStatsOverviewTab(controller: controller),
                ChatStatsActivityTab(controller: controller),
                ChatStatsEngagementTab(controller: controller),
                ChatStatsContentTab(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Page-level window selector — visible above every tab (not per-tab, unlike
/// the Activity tab's own chart-zoom chips) since it re-scopes every section's
/// underlying data, not just one chart's display.
class _TimeframeSelector extends StatelessWidget {
  const _TimeframeSelector({required this.controller});

  final ChatStatsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.timeframe.value;
      // Sized to content (no guessed fixed height) so there's no slack below
      // the chips beyond the explicit bottom padding.
      return Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 14.0, 12.0, 4.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tf in StatsTimeframe.values) ...[
                BBChip(
                  label: Text(tf.label),
                  selected: tf == selected,
                  onSelected: (_) => controller.setTimeframe(tf),
                  selectedColor: context.theme.colorScheme.primary.withValues(alpha: 0.22),
                  labelStyle: TextStyle(
                    fontSize: 12.0,
                    fontWeight: tf == selected ? FontWeight.bold : FontWeight.normal,
                    color: tf == selected ? context.theme.colorScheme.primary : null,
                  ),
                ),
                const SizedBox(width: 8.0),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.controller});

  final ChatStatsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = controller.progress.value;
      // No fixed height when idle — the old always-reserved 34.0 box left a
      // dead gap between the timeframe chips and the tab content even while
      // no progress was showing.
      if (p.stage == StatsStage.idle) return const SizedBox.shrink();
      return SizedBox(
        height: 34.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: LinearProgressIndicator(
                  value: p.fraction,
                  minHeight: 3.0,
                  backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                  color: context.theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(p.label, style: context.theme.textTheme.bodySmall),
            ],
          ),
        ),
      );
    });
  }
}
