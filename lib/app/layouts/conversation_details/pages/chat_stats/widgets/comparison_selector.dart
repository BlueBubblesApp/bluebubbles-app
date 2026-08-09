import 'package:bluebubbles/app/layouts/conversation_details/pages/chat_stats/chat_stats_controller.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Page-level "compare against" trigger, shown once above every tab —
/// standardizes which single target every You-vs-Group/Them widget on the
/// page compares against, instead of each widget hardcoding "everyone but
/// me" for a group chat. Only meaningful for group chats; a 1:1 chat has
/// exactly one possible comparison target already, so this renders nothing
/// there.
class ComparisonSelector extends StatelessWidget {
  const ComparisonSelector({super.key, required this.controller});

  final ChatStatsController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.isGroup) return const SizedBox.shrink();

    return Obx(() {
      final selectedId = controller.comparisonParticipantId.value;
      final label = selectedId == null ? "Whole Group" : (controller.participants[selectedId]?.displayName ?? "Unknown");

      return Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 10.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            borderRadius: BorderRadius.circular(16.0),
            onTap: () => _pick(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: context.theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Compare vs. ",
                    style: context.theme.textTheme.labelSmall?.copyWith(color: context.theme.colorScheme.outline),
                  ),
                  Flexible(
                    child: Text(
                      label,
                      style: context.theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 2.0),
                  Icon(
                    context.iOS ? CupertinoIcons.chevron_down : Icons.arrow_drop_down,
                    size: 16.0,
                    color: context.theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _pick(BuildContext context) async {
    // Ranked by message count when the leaderboard's available (most-active
    // participant first — the likeliest comparison target); alphabetical
    // fallback before Overview has computed.
    final overview = controller.stats.value?.overview;
    final others = controller.participants.keys.where((id) => id != kMeParticipantId).toList();
    if (overview != null) {
      final countById = {for (final c in overview.leaderboard) c.participantId: c.count};
      others.sort((a, b) => (countById[b] ?? 0).compareTo(countById[a] ?? 0));
    } else {
      others.sort(
        (a, b) => (controller.participants[a]?.displayName ?? "").compareTo(controller.participants[b]?.displayName ?? ""),
      );
    }

    // Uses `kWholeGroupComparisonId` rather than `null` for the "Whole Group"
    // option — see its doc comment for why `null` can't be a selectable value
    // here (it's indistinguishable from "dialog dismissed with no choice").
    final selection = await showBBListSelector<int>(
      context: context,
      title: "Compare Against",
      options: [
        const BBListSelectorOption(label: "Whole Group", value: kWholeGroupComparisonId),
        for (final id in others)
          BBListSelectorOption(label: controller.participants[id]?.displayName ?? "Unknown", value: id),
      ],
    );
    if (selection == null) return; // dismissed without choosing
    await controller.setComparisonParticipant(selection == kWholeGroupComparisonId ? null : selection);
  }
}
