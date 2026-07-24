import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Quick-filter chip row for custom groups, shown above the chat list when
/// [Settings.showCustomGroupFilterChips] is enabled and at least one custom
/// group exists. Tapping a chip toggles that group in the same
/// [ChatsSvc.chatListFilters] state the Chat Filters sheet reads/writes, so
/// the two stay in sync.
class CustomGroupFilterChipRow extends StatelessWidget {
  const CustomGroupFilterChipRow({super.key, this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4)});

  /// Padding around the horizontally-scrolling chip list. Callers can widen
  /// the top/bottom insets to add extra separation from surrounding content
  /// (e.g. the chat list edge) without affecting the other skins.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!SettingsSvc.settings.showCustomGroupFilterChips.value) return const SizedBox.shrink();
      final groups = CustomGroupsSvc.groups;
      if (groups.isEmpty) return const SizedBox.shrink();

      final current = ChatsSvc.chatListFilters.value.customGroupIds;

      // Read chatListVersion so this rebuilds when chats are added/removed, and
      // read each ChatState's hasUnreadMessage below so it rebuilds when any
      // chat's read status changes.
      ChatsSvc.chatListVersion.value;
      final unreadStates = ChatsSvc.chatStates.values.where((s) => s.hasUnreadMessage.value).toList();
      final unreadCounts = <int, int>{
        // Membership is read from `group.chats` (the group's own ToMany,
        // refreshed whenever CustomGroupsSvc reloads) rather than
        // `s.chat.customGroups` — that backlink is lazily cached per Chat
        // instance and goes stale as soon as membership changes elsewhere
        // (e.g. the conversation peek view's "Add to Custom Group" action).
        for (final group in groups)
          group.id!: unreadStates.where((s) => group.chats.any((c) => c.guid == s.chat.guid)).length,
      };

      return SizedBox(
        // Extra top room so the overlapping badge isn't clipped.
        height: 50 + padding.vertical,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padding.copyWith(top: padding.top + 6),
          itemCount: groups.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final group = groups[index];
            final selected = current.contains(group.id);
            final unreadCount = unreadCounts[group.id] ?? 0;
            return Badge(
              isLabelVisible: group.showUnreadBadge && unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
              backgroundColor: context.theme.colorScheme.primary,
              textColor: context.theme.colorScheme.onPrimary,
              child: BBChip(
                label: Text(
                  group.name,
                  style: TextStyle(
                    color: selected ? context.theme.colorScheme.primary : null,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                ),
                selected: selected,
                showCheckmark: false,
                onPressed: () {
                  final next = Set<int>.from(current);
                  if (selected) {
                    next.remove(group.id);
                  } else {
                    next.add(group.id!);
                  }
                  ChatsSvc.chatListFilters.value = ChatsSvc.chatListFilters.value.copyWith(customGroupIds: next);
                },
                onLongPress: () {
                  // Long-press singles out this group, replacing any other
                  // selected groups, instead of toggling it alongside them.
                  ChatsSvc.chatListFilters.value =
                      ChatsSvc.chatListFilters.value.copyWith(customGroupIds: {group.id!});
                },
              ),
            );
          },
        ),
      );
    });
  }
}
