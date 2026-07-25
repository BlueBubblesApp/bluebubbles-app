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

      final filters = ChatsSvc.chatListFilters.value;
      final current = filters.customGroupIds;

      // Read chatListVersion so this rebuilds when chats are added/removed, and
      // read each ChatState's hasUnreadMessage below so it rebuilds when any
      // chat's read status changes.
      ChatsSvc.chatListVersion.value;
      final unreadStates = ChatsSvc.chatStates.values.where((s) => s.hasUnreadMessage.value).toList();
      // Membership is read from `group.chats` (the group's own ToMany,
      // refreshed whenever CustomGroupsSvc reloads) rather than
      // `s.chat.customGroups` — that backlink is lazily cached per Chat
      // instance and goes stale as soon as membership changes elsewhere
      // (e.g. the conversation peek view's "Add to Custom Group" action).
      final groupedGuids = groups.expand((g) => g.chats).map((c) => c.guid).toSet();
      final unreadCounts = <int, int>{
        for (final group in groups)
          group.id!: unreadStates.where((s) => group.chats.any((c) => c.guid == s.chat.guid)).length,
      };
      final ungroupedUnreadCount = unreadStates.where((s) => !groupedGuids.contains(s.chat.guid)).length;
      final showUngroupedChip = current.isNotEmpty || filters.showUngroupedOnly;

      return SizedBox(
        // Extra top room so the overlapping badge isn't clipped.
        height: 50 + padding.vertical,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0.0, 0.9, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: padding.copyWith(top: padding.top + 6, right: 0),
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
                          ChatsSvc.chatListFilters.value = ChatsSvc.chatListFilters.value
                              .copyWith(customGroupIds: next, showUngroupedOnly: false);
                        },
                        onLongPress: () {
                          // Long-press singles out this group, replacing any other
                          // selected groups, instead of toggling it alongside them.
                          ChatsSvc.chatListFilters.value = ChatsSvc.chatListFilters.value
                              .copyWith(customGroupIds: {group.id!}, showUngroupedOnly: false);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 8, right: padding.right, top: padding.top + 8),
              child: AnimatedSwitcher(
                duration: !showUngroupedChip ? const Duration(milliseconds: 500) : const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
                  child: child,
                ),
                child: !showUngroupedChip
                    ? const SizedBox.shrink()
                    : _UngroupedChip(
                        key: const ValueKey('ungrouped-chip'),
                        selected: filters.showUngroupedOnly,
                        unreadCount: ungroupedUnreadCount,
                        onPressed: () {
                          final f = ChatsSvc.chatListFilters.value;
                          ChatsSvc.chatListFilters.value = f.copyWith(
                            customGroupIds: <int>{},
                            showUngroupedOnly: !f.showUngroupedOnly,
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Small round chip representing chats that don't belong to any custom
/// group. Pops in/out of [CustomGroupFilterChipRow] as the selection
/// changes — see [CustomGroupFilterChipRow] for the visibility rule.
class _UngroupedChip extends StatelessWidget {
  const _UngroupedChip({
    super.key,
    required this.selected,
    required this.unreadCount,
    required this.onPressed,
  });

  final bool selected;
  final int unreadCount;
  final VoidCallback onPressed;

  // Matches RawChip's default unlabeled height so this sits flush with the
  // text chips beside it.
  static const double _size = 38;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? context.theme.colorScheme.primary : context.theme.colorScheme.outline;
    return Badge(
      isLabelVisible: unreadCount > 0,
      label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
      backgroundColor: context.theme.colorScheme.primary,
      textColor: context.theme.colorScheme.onPrimary,
      child: Material(
        color: selected ? context.theme.colorScheme.outline.withValues(alpha: 0.2) : Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: context.theme.colorScheme.outline.withValues(alpha: 0.2))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(Icons.inbox_outlined, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}
