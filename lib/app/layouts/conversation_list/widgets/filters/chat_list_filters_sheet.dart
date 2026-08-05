import 'package:bluebubbles/app/components/bb_chip.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/filters/chat_list_filters.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/custom_groups/custom_groups_panel.dart';
import 'package:bluebubbles/app/layouts/settings/settings_page.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pull_down_button/pull_down_button.dart';

/// Opens the conversation-list filter bottom sheet. Each section (Status,
/// Sender, Chat Type) is single-select via chips, but the sections combine
/// with AND semantics — e.g. picking "Unread" + "Group Chats" shows only
/// unread group chats.
void showChatListFilterSheet(
  BuildContext pageContext, {
  required ChatListFilters current,
  required ValueChanged<ChatListFilters> onChanged,
}) {
  HapticFeedback.lightImpact();

  // The legacy "Filter Unknown Senders" setting already owns known/unknown
  // sender classification globally (see ChatsService.getFilteredChats) — if a
  // stale Sender selection was persisted (e.g. via a saved default filter) from
  // before this setting was turned on, normalize it so the greyed-out section
  // doesn't silently show an inert selected chip.
  final legacyUnknownSenderFilterActive = SettingsSvc.settings.filterUnknownSenders.value;
  var current0 = current;
  if (legacyUnknownSenderFilterActive && current0.senderFilter != ChatSenderFilter.all) {
    current0 = current0.copyWith(senderFilter: ChatSenderFilter.all);
    onChanged(current0);
  }

  showModalBottomSheet<void>(
    context: pageContext,
    backgroundColor: pageContext.theme.colorScheme.surfaceContainerHighest,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      var currentFilters = current0;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final labelStyle = TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Theme.of(context).colorScheme.onSurface,
          );
          final sectionLabelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              );
          final primaryColor = Theme.of(context).colorScheme.primary;

          void update({
            ChatReadFilter? readFilter,
            ChatSenderFilter? senderFilter,
            ChatTypeFilter? typeFilter,
            ChatMuteFilter? muteFilter,
            ChatServiceFilter? serviceFilter,
          }) {
            currentFilters = currentFilters.copyWith(
              readFilter: readFilter,
              // Sender doesn't meaningfully apply to group chats (a group is always
              // treated as a "known" sender regardless of its participants) — reset
              // it to All whenever the user switches to the Group Chats chip so the
              // greyed-out Sender section doesn't silently hold a stale selection.
              senderFilter: typeFilter == ChatTypeFilter.group ? ChatSenderFilter.all : senderFilter,
              typeFilter: typeFilter,
              muteFilter: muteFilter,
              serviceFilter: serviceFilter,
            );
            onChanged(currentFilters);
            setSheetState(() {});
          }

          void toggleGroup(int groupId) {
            final next = Set<int>.from(currentFilters.customGroupIds);
            if (!next.remove(groupId)) next.add(groupId);
            currentFilters = currentFilters.copyWith(customGroupIds: next);
            onChanged(currentFilters);
            setSheetState(() {});
          }

          void resetFilters() {
            currentFilters = const ChatListFilters();
            onChanged(currentFilters);
            setSheetState(() {});
          }

          void loadSavedDefault() {
            currentFilters = ChatsSvc.savedDefaultChatListFilters;
            onChanged(currentFilters);
            setSheetState(() {});
          }

          void resetFiltersAndSave() {
            resetFilters();
            ChatsSvc.saveChatListFiltersAsDefault();
            showToast("Reset filters and saved as default");
          }

          Widget sectionLabel(String label) => Padding(
                padding: const EdgeInsets.only(top: 16, left: 10),
                child: Text(label, style: sectionLabelStyle),
              );

          Widget chipWrap(List<Widget> chips) => Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, left: 10, right: 10),
                  child: Wrap(spacing: 6, runSpacing: 6, children: chips),
                ),
              );

          Widget filterChip(String label, bool selected, VoidCallback onTap, {bool enabled = true}) {
            return Opacity(
              opacity: enabled ? 1.0 : 0.4,
              child: BBChip(
                showCheckmark: true,
                selected: selected,
                checkmarkColor: primaryColor,
                tapEnabled: enabled,
                label: Text(label, style: labelStyle),
                onSelected: enabled ? (_) => onTap() : null,
              ),
            );
          }

          final matchesDefault = currentFilters == ChatsSvc.savedDefaultChatListFilters;
          final itemTheme = PullDownMenuItemTheme(
            textStyle: TextStyle(color: context.theme.colorScheme.onSurface),
            onHoverTextColor: context.theme.colorScheme.onSurface,
            onHoverBackgroundColor: context.theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            subtitleStyle: TextStyle(color: context.theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          );
          final routeBackgroundColor = context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9);

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 36, top: 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ThemeSwitcher(
                        iOSSkin: PullDownButton(
                          animationAlignmentOverride: Alignment.topLeft,
                          routeTheme: PullDownMenuRouteTheme(backgroundColor: routeBackgroundColor),
                          itemBuilder: (context) => [
                            PullDownMenuItem(
                              itemTheme: itemTheme,
                              title: "Clear All Filters",
                              icon: CupertinoIcons.clear_circled,
                              enabled: currentFilters.hasActiveFilter,
                              onTap: resetFilters,
                            ),
                            PullDownMenuItem(
                              itemTheme: itemTheme,
                              title: "Reset Filters & Save",
                              icon: CupertinoIcons.arrow_uturn_left,
                              enabled: currentFilters.hasActiveFilter || !matchesDefault,
                              onTap: resetFiltersAndSave,
                            ),
                            PullDownMenuItem(
                              itemTheme: itemTheme,
                              title: "Load Saved Default",
                              icon: CupertinoIcons.arrow_down_doc,
                              enabled: !matchesDefault,
                              onTap: loadSavedDefault,
                            ),
                          ],
                          buttonBuilder: (context, showMenu) => IconButton(
                            tooltip: "Reset Filters",
                            icon: const Icon(CupertinoIcons.restart),
                            onPressed: showMenu,
                          ),
                        ),
                        materialSkin: MenuAnchor(
                          style: MenuStyle(
                            backgroundColor: WidgetStatePropertyAll(context.theme.colorScheme.surfaceContainerHighest),
                            shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          ),
                          menuChildren: [
                            MenuItemButton(
                              leadingIcon: const Icon(Icons.clear_all),
                              onPressed: currentFilters.hasActiveFilter ? resetFilters : null,
                              child: const Text("Clear All Filters"),
                            ),
                            MenuItemButton(
                              leadingIcon: const Icon(Icons.settings_backup_restore),
                              onPressed: currentFilters.hasActiveFilter || !matchesDefault ? resetFiltersAndSave : null,
                              child: const Text("Reset Filters & Save"),
                            ),
                            MenuItemButton(
                              leadingIcon: const Icon(Icons.download_outlined),
                              onPressed: !matchesDefault ? loadSavedDefault : null,
                              child: const Text("Load Saved Default"),
                            ),
                          ],
                          builder: (context, controller, child) => IconButton(
                            tooltip: "Reset Filters",
                            icon: const Icon(Icons.restore),
                            onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            "Chat Filters",
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: "Save as Default",
                        icon: Icon(
                            currentFilters.hasActiveFilter && matchesDefault ? Icons.bookmark : Icons.bookmark_outline),
                        onPressed: () {
                          final wasActive = currentFilters.hasActiveFilter;
                          ChatsSvc.saveChatListFiltersAsDefault();
                          showToast(wasActive ? "Saved as default filters" : "Cleared saved default filters");
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                  Obx(() {
                    final groups = CustomGroupsSvc.groups;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionLabel("Custom Groups"),
                        if (groups.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10, top: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "No custom groups created",
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(sheetContext).pop(); // close the sheet
                                    Navigator.of(pageContext).push(
                                      ThemeSwitcher.buildPageRoute(
                                        builder: (BuildContext context) {
                                          return const SettingsPage(initialPage: CustomGroupsPanel());
                                        },
                                      ),
                                    );
                                  },
                                  child: const Text("Create one"),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            height: 40,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(left: 10, right: 10, top: 4),
                              child: Row(
                                children: [
                                  for (final group in groups) ...[
                                    filterChip(group.name, currentFilters.customGroupIds.contains(group.id),
                                        () => toggleGroup(group.id!)),
                                    const SizedBox(width: 6),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                  sectionLabel("Status"),
                  chipWrap([
                    filterChip("All Messages", currentFilters.readFilter == ChatReadFilter.all,
                        () => update(readFilter: ChatReadFilter.all)),
                    filterChip("Unread Messages", currentFilters.readFilter == ChatReadFilter.unread,
                        () => update(readFilter: ChatReadFilter.unread)),
                  ]),
                  sectionLabel("Chat Type"),
                  chipWrap([
                    filterChip("All", currentFilters.typeFilter == ChatTypeFilter.all,
                        () => update(typeFilter: ChatTypeFilter.all)),
                    filterChip("Group Chats", currentFilters.typeFilter == ChatTypeFilter.group,
                        () => update(typeFilter: ChatTypeFilter.group)),
                    filterChip("Direct Messages", currentFilters.typeFilter == ChatTypeFilter.direct,
                        () => update(typeFilter: ChatTypeFilter.direct)),
                  ]),
                  sectionLabel("Sender"),
                  if (legacyUnknownSenderFilterActive)
                    Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10, top: 2),
                      child: Text(
                        "Controlled by \"Filter Unknown Senders\" in Settings",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ),
                  chipWrap([
                    filterChip("All", currentFilters.senderFilter == ChatSenderFilter.all,
                        () => update(senderFilter: ChatSenderFilter.all),
                        enabled: currentFilters.typeFilter != ChatTypeFilter.group && !legacyUnknownSenderFilterActive),
                    filterChip("Known Senders", currentFilters.senderFilter == ChatSenderFilter.known,
                        () => update(senderFilter: ChatSenderFilter.known),
                        enabled: currentFilters.typeFilter != ChatTypeFilter.group && !legacyUnknownSenderFilterActive),
                    filterChip("Unknown Senders", currentFilters.senderFilter == ChatSenderFilter.unknown,
                        () => update(senderFilter: ChatSenderFilter.unknown),
                        enabled: currentFilters.typeFilter != ChatTypeFilter.group && !legacyUnknownSenderFilterActive),
                  ]),
                  sectionLabel("Mute Status"),
                  chipWrap([
                    filterChip("All", currentFilters.muteFilter == ChatMuteFilter.all,
                        () => update(muteFilter: ChatMuteFilter.all)),
                    filterChip("Muted", currentFilters.muteFilter == ChatMuteFilter.muted,
                        () => update(muteFilter: ChatMuteFilter.muted)),
                    filterChip("Unmuted", currentFilters.muteFilter == ChatMuteFilter.unmuted,
                        () => update(muteFilter: ChatMuteFilter.unmuted)),
                  ]),
                  sectionLabel("Message Service"),
                  chipWrap([
                    filterChip("All", currentFilters.serviceFilter == ChatServiceFilter.all,
                        () => update(serviceFilter: ChatServiceFilter.all)),
                    filterChip("iMessage", currentFilters.serviceFilter == ChatServiceFilter.iMessage,
                        () => update(serviceFilter: ChatServiceFilter.iMessage)),
                    filterChip("SMS & Other", currentFilters.serviceFilter == ChatServiceFilter.other,
                        () => update(serviceFilter: ChatServiceFilter.other)),
                  ]),
                  // Future "Category" section, pending Message.isServiceMessage / Message.isSpam:
                  // sectionLabel("Category"),
                  // chipWrap([
                  //   filterChip("2FA Codes", ...),
                  //   filterChip("Spam", ...),
                  //   filterChip("Promotions", ...),
                  //   filterChip("Transactions", ...),
                  // ]),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
