import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/chat_stats_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/charts/bar_chart.dart';
import 'package:bluebubbles/app/components/charts/donut_chart.dart';
import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/widgets/participant_bar.dart';
import 'package:bluebubbles/app/components/charts/section_skeleton.dart';
import 'package:bluebubbles/app/components/charts/stat_tile.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The content tab — message length, top emoji/words, reaction breakdown,
/// attachment mix, effects, edited/unsent, audio. Gated behind
/// an explicit "Analyze Content" tap rather than computed on tab open: it's
/// the only section that touches full message text, and top words/emoji are
/// more exposing in a screenshot-friendly view than any other tab.
/// See `docs/feature-planning/chat-stats/tasks/11-content-tab.md`.
class ChatStatsContentTab extends StatefulWidget {
  const ChatStatsContentTab({super.key, required this.controller});

  final ChatStatsController controller;

  @override
  State<ChatStatsContentTab> createState() => _ChatStatsContentTabState();
}

class _ChatStatsContentTabState extends State<ChatStatsContentTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() {
      final content = widget.controller.stats.value?.content;
      final progress = widget.controller.progress.value;
      final error = widget.controller.error.value;
      // Not just `progress.stage == StatsStage.computingContent`: a
      // page-level timeframe change resets `stats.value` (and so `content`)
      // for every previously-loaded stage up front, then recomputes them one
      // at a time — Content's turn in that sequence might not have started
      // yet, so `progress` could still read another stage while `content` is
      // already null. Once Content's been analyzed at least once this
      // session, any gap like that should read as "reloading", not "opt in
      // again".
      final isLoading = progress.stage == StatsStage.computingContent || widget.controller.hasAnalyzedContent;

      if (content == null && error != null) {
        return _ErrorState(onRetry: () => widget.controller.ensureSection(StatsStage.computingContent, force: true));
      }

      if (content == null) {
        if (isLoading) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 36.0),
            children: const [SectionSkeleton(height: 220.0), SizedBox(height: 12.0), SectionSkeleton(height: 220.0)],
          );
        }
        return _AnalyzePrompt(controller: widget.controller);
      }

      return _ContentBody(controller: widget.controller, content: content);
    });
  }
}

class _AnalyzePrompt extends StatelessWidget {
  const _AnalyzePrompt({required this.controller});

  final ChatStatsController controller;

  @override
  Widget build(BuildContext context) {
    final isLarge = controller.tier == StatsDetailTier.large;
    final isCupertino = SettingsSvc.settings.skin.value == Skins.iOS;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isCupertino ? CupertinoIcons.text_bubble : Icons.article_outlined,
                size: 40.0, color: context.theme.colorScheme.outline),
            const SizedBox(height: 12.0),
            Text(
              "Analyze Content",
              style: context.theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            Text(
              "Reads message text on this device to surface top words, emoji, and reaction "
              "breakdowns. Nothing leaves your device.${isLarge ? ' Limited to the most recent messages on large chats.' : ''}",
              style: context.theme.textTheme.bodySmall?.copyWith(color: context.theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            FilledButton(
              onPressed: () => controller.ensureSection(StatsStage.computingContent),
              child: const Text("Analyze Content"),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentBody extends StatelessWidget {
  const _ContentBody({required this.controller, required this.content});

  final ChatStatsController controller;
  final ContentStats content;

  /// The current comparison target's display label — "Group"/"Them" when
  /// comparing against everyone, or the selected participant's name.
  /// Content is only ever recomputed (via `setComparisonParticipant`) when
  /// this selection actually changes, so `content` itself and this label
  /// always land in the same rebuild — no separate `Obx` needed here.
  String get _comparisonLabel {
    final id = controller.comparisonParticipantId.value;
    if (id == null) return controller.isGroup ? "Group" : "Them";
    return controller.participants[id]?.displayName ?? "Them";
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 36.0),
      children: [
        if (content.textCoverage < 0.95) _CoverageCaption(content: content),
        if (content.windowed) ...[
          Text(
            "Analyzed the most recent ${content.analyzedMessageCount.formatStatCount()} messages with text.",
            style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.outline),
          ),
          const SizedBox(height: 12.0),
        ],
        StatTileGrid(tiles: [
          StatTile(value: content.avgLengthMine.toStringAsFixed(0), label: "Your Avg Length", caption: "characters"),
          StatTile(value: content.avgLengthTheirs.toStringAsFixed(0), label: "$_comparisonLabel Avg Length", caption: "characters"),
          StatTile(value: "${content.editedCount}", label: "Edited"),
          StatTile(value: "${content.unsentCount}", label: "Unsent"),
        ]),
        const SizedBox(height: 24.0),
        Text("Message Length", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _lengthChart(context),
        if (content.messageLengthLeaderboard.length >= 2) ...[
          const SizedBox(height: 28.0),
          Text("Sends the Longest Messages", style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 10.0),
          _LengthLeaderboard(
            entries: content.messageLengthLeaderboard,
            participants: controller.participants,
            chat: controller.chat,
          ),
        ],
        const SizedBox(height: 28.0),
        Text("Top Emoji", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _EmojiSection(content: content, comparisonLabel: _comparisonLabel),
        const SizedBox(height: 28.0),
        Text("Top Words", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _WordsSection(content: content),
        const SizedBox(height: 28.0),
        Text("Reactions by Type", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _ReactionsSection(content: content, comparisonLabel: _comparisonLabel),
        const SizedBox(height: 28.0),
        Text("Attachment Mix", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _AttachmentMixSection(content: content),
        if (content.effectIdCounts.isNotEmpty) ...[
          const SizedBox(height: 28.0),
          Text("Effects Used", style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 10.0),
          _EffectsSection(content: content),
        ],
        if (content.topSwearWords.isNotEmpty) ...[
          const SizedBox(height: 28.0),
          Text("Colorful Language", style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 10.0),
          _SwearWordsSection(content: content, comparisonLabel: _comparisonLabel),
        ],
        const SizedBox(height: 28.0),
        Text("Second Thoughts", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _CorrectionRateSection(content: content, comparisonLabel: _comparisonLabel),
        const SizedBox(height: 28.0),
        Text("Audio Messages", style: context.theme.textTheme.titleMedium),
        const SizedBox(height: 10.0),
        _audioSection(context),
        const SizedBox(height: 12.0),
      ],
    );
  }

  Widget _lengthChart(BuildContext context) {
    final mineColor = context.theme.colorScheme.primary;
    final theirsColor = context.theme.colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14.0,
          children: [
            _swatch(context, mineColor, "You"),
            _swatch(context, theirsColor, _comparisonLabel),
          ],
        ),
        const SizedBox(height: 8.0),
        StatBarChart(
          groups: [
            for (var i = 0; i < kContentLengthBucketLabels.length; i++)
              BarGroupSpec(
                label: kContentLengthBucketLabels[i],
                bars: [
                  BarValueSpec(value: content.lengthHistogramMine[i].toDouble(), color: mineColor),
                  BarValueSpec(value: content.lengthHistogramTheirs[i].toDouble(), color: theirsColor),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _audioSection(BuildContext context) {
    final playedPct = content.audioPlayedRatio == null ? "—" : "${(content.audioPlayedRatio! * 100).round()}%";
    return StatTileGrid(tiles: [
      StatTile(value: content.audioSent.formatStatCount(), label: "Audio Sent"),
      StatTile(value: content.audioReceived.formatStatCount(), label: "Audio Received"),
      StatTile(value: playedPct, label: "Received & Played"),
    ]);
  }
}

/// Ranked participant list for the longest/shortest message-length sections —
/// [entries] is expected pre-sorted (rank == list position), so the same
/// widget renders both directions off `messageLengthLeaderboard` and its
/// reverse without knowing which direction it's showing.
class _LengthLeaderboard extends StatefulWidget {
  const _LengthLeaderboard({required this.entries, required this.participants, required this.chat});

  final List<ParticipantLengthStats> entries;
  final Map<int, ParticipantInfo> participants;
  final Chat chat;

  @override
  State<_LengthLeaderboard> createState() => _LengthLeaderboardState();
}

class _LengthLeaderboardState extends State<_LengthLeaderboard> {
  static const int _cap = 10;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final maxAvg = widget.entries.isEmpty ? 1.0 : widget.entries.map((e) => e.avgLength).reduce((a, b) => a > b ? a : b);
    final visible = _showAll ? widget.entries : widget.entries.take(_cap).toList();
    final currentHandleIds = widget.chat.handles.map((h) => h.id).whereType<int>().toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++)
          _LengthLeaderboardRow(
            rank: i + 1,
            entry: visible[i],
            participants: widget.participants,
            maxAvg: maxAvg,
            isDeparted: visible[i].participantId != kMeParticipantId && !currentHandleIds.contains(visible[i].participantId),
          ),
        if (!_showAll && widget.entries.length > _cap)
          TextButton(
            onPressed: () => setState(() => _showAll = true),
            child: Text("Show all (${widget.entries.length})"),
          ),
      ],
    );
  }
}

class _LengthLeaderboardRow extends StatelessWidget {
  const _LengthLeaderboardRow({
    required this.rank,
    required this.entry,
    required this.participants,
    required this.maxAvg,
    required this.isDeparted,
  });

  final int rank;
  final ParticipantLengthStats entry;
  final Map<int, ParticipantInfo> participants;
  final double maxAvg;
  final bool isDeparted;

  @override
  Widget build(BuildContext context) {
    final info = participants[entry.participantId];
    final isMe = entry.participantId == kMeParticipantId;
    final handle = isMe ? null : Database.handles.get(entry.participantId);
    final share = maxAvg == 0 ? 0.0 : entry.avgLength / maxAvg;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 20.0,
            child: Text(
              "$rank",
              textAlign: TextAlign.center,
              style: context.theme.textTheme.labelLarge?.copyWith(color: context.theme.colorScheme.outline),
            ),
          ),
          const SizedBox(width: 8.0),
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
                    color: participantColor(context, entry.participantId, participants),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10.0),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${entry.avgLength.round()}", style: context.theme.textTheme.bodyMedium),
              Text(
                "${entry.messageCount.formatStatCount()} msgs",
                style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverageCaption extends StatelessWidget {
  const _CoverageCaption({required this.content});

  final ContentStats content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        "Only ${(content.textCoverage * 100).round()}% of messages have readable text — some older "
        "messages may be missing from these numbers.",
        style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.outline),
      ),
    );
  }
}

class _EmojiSection extends StatelessWidget {
  const _EmojiSection({required this.content, required this.comparisonLabel});

  final ContentStats content;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final top = content.topEmoji.take(10).toList();
    if (top.isEmpty) {
      return _emptyText(context, "No emoji yet.");
    }
    final mineColor = context.theme.colorScheme.primary;
    final theirsColor = context.theme.colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14.0,
          children: [
            _swatch(context, mineColor, "You"),
            _swatch(context, theirsColor, comparisonLabel),
          ],
        ),
        const SizedBox(height: 8.0),
        StatBarChart(
          barWidth: 10.0,
          groups: [
            for (final e in top)
              BarGroupSpec(
                label: e.emoji,
                bars: [
                  BarValueSpec(value: e.mineCount.toDouble(), color: mineColor),
                  BarValueSpec(value: e.theirsCount.toDouble(), color: theirsColor),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _WordsSection extends StatelessWidget {
  const _WordsSection({required this.content});

  final ContentStats content;

  @override
  Widget build(BuildContext context) {
    final top = content.topWords.take(15).toList();
    if (top.isEmpty) return _emptyText(context, "Not enough text yet.");
    return StatBarChart(
      height: 220.0,
      barWidth: 12.0,
      rotateLabels: true,
      showYAxis: true,
      groups: [
        for (final w in top)
          BarGroupSpec(label: w.word, bars: [BarValueSpec(value: w.count.toDouble(), color: context.theme.colorScheme.primary)]),
      ],
    );
  }
}

class _ReactionsSection extends StatelessWidget {
  const _ReactionsSection({required this.content, required this.comparisonLabel});

  final ContentStats content;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final types = ReactionTypes.toList();
    final anyData = types.any((t) => (content.reactionsGivenByType[t] ?? 0) > 0 || (content.reactionsReceivedByType[t] ?? 0) > 0);
    if (!anyData) return _emptyText(context, "No reactions yet.");

    final givenColor = context.theme.colorScheme.primary;
    final receivedColor = context.theme.colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14.0,
          children: [
            _swatch(context, givenColor, "You"),
            _swatch(context, receivedColor, comparisonLabel),
          ],
        ),
        const SizedBox(height: 8.0),
        StatBarChart(
          groups: [
            for (final t in types)
              BarGroupSpec(
                label: ReactionTypes.reactionToEmoji[t] ?? t,
                bars: [
                  BarValueSpec(value: (content.reactionsGivenByType[t] ?? 0).toDouble(), color: givenColor),
                  BarValueSpec(value: (content.reactionsReceivedByType[t] ?? 0).toDouble(), color: receivedColor),
                ],
              ),
          ],
        ),
        if (content.reactionsTakenBack > 0) ...[
          const SizedBox(height: 8.0),
          Text(
            "Taken back: ${content.reactionsTakenBack}",
            style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.outline),
          ),
        ],
      ],
    );
  }
}

class _AttachmentMixSection extends StatelessWidget {
  const _AttachmentMixSection({required this.content});

  final ContentStats content;

  @override
  Widget build(BuildContext context) {
    final entries = content.attachmentMimeCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return _emptyText(context, "No attachments yet.");
    final palette = [
      context.theme.colorScheme.primary,
      context.theme.colorScheme.secondary,
      context.theme.colorScheme.tertiary,
      context.theme.colorScheme.outline,
      context.theme.colorScheme.outlineVariant,
    ];
    return DonutChart(
      slices: [
        for (var i = 0; i < entries.length; i++)
          DonutSlice(
            label: entries[i].key[0].toUpperCase() + entries[i].key.substring(1),
            value: entries[i].value.toDouble(),
            color: palette[i % palette.length],
          ),
      ],
    );
  }
}

class _EffectsSection extends StatelessWidget {
  const _EffectsSection({required this.content});

  final ContentStats content;

  @override
  Widget build(BuildContext context) {
    final entries = content.effectIdCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return StatBarChart(
      showYAxis: true,
      groups: [
        for (final e in entries)
          BarGroupSpec(
            label: effectMap.entries.firstWhereOrNull((entry) => entry.value == e.key)?.key ?? "other",
            bars: [BarValueSpec(value: e.value.toDouble(), color: context.theme.colorScheme.primary)],
          ),
      ],
    );
  }
}

/// Mine-vs-theirs bar chart over the curated curse-word vocabulary — reuses
/// the same paired-bar shape as [_EmojiSection] and [_ReactionsSection].
class _SwearWordsSection extends StatelessWidget {
  const _SwearWordsSection({required this.content, required this.comparisonLabel});

  final ContentStats content;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final top = content.topSwearWords.take(10).toList();
    final mineColor = context.theme.colorScheme.primary;
    final theirsColor = context.theme.colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14.0,
          children: [
            _swatch(context, mineColor, "You"),
            _swatch(context, theirsColor, comparisonLabel),
          ],
        ),
        const SizedBox(height: 8.0),
        StatBarChart(
          showYAxis: true,
          groups: [
            for (final w in top)
              BarGroupSpec(
                label: w.word,
                bars: [
                  BarValueSpec(value: w.mineCount.toDouble(), color: mineColor),
                  BarValueSpec(value: w.theirsCount.toDouble(), color: theirsColor),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Share of each side's messages that were later edited or unsent — a
/// derived rate (not a raw count, unlike the Edited/Unsent tiles above) so
/// it stays comparable between two people who send very different volumes.
class _CorrectionRateSection extends StatelessWidget {
  const _CorrectionRateSection({required this.content, required this.comparisonLabel});

  final ContentStats content;
  final String comparisonLabel;

  String _format(double? rate) => rate == null ? "—" : "${(rate * 100).toStringAsFixed(1)}%";

  @override
  Widget build(BuildContext context) {
    return StatTileGrid(tiles: [
      StatTile(
        value: _format(content.correctionRateMine),
        label: "Your Correction Rate",
        caption: "edited or unsent",
      ),
      StatTile(
        value: _format(content.correctionRateTheirs),
        label: "$comparisonLabel Correction Rate",
        caption: "edited or unsent",
      ),
    ]);
  }
}

Widget _emptyText(BuildContext context, String text) {
  return Text(text, style: context.theme.textTheme.bodyMedium?.copyWith(color: context.theme.colorScheme.outline));
}

/// Colored-dot + label legend entry — shared by every section with a
/// mine-vs-other paired chart (Top Emoji, Reactions by Type).
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
