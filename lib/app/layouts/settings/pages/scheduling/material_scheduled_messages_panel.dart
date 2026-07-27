import 'package:bluebubbles/app/layouts/settings/pages/scheduling/create_scheduled_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/scheduling/scheduled_messages_mixin.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MaterialScheduledMessagesPanel extends StatefulWidget {
  const MaterialScheduledMessagesPanel({super.key});

  @override
  State<MaterialScheduledMessagesPanel> createState() => _MaterialScheduledMessagesPanelState();
}

class _MaterialScheduledMessagesPanelState extends State<MaterialScheduledMessagesPanel>
    with ThemeHelpers, ScheduledMessagesMixin {
  @override
  void initState() {
    super.initState();
    initScheduled();
  }

  Widget _buildStatsHeader(BuildContext context) {
    final pendingCount = oneTime.length;
    final recurringCount = recurring.length;
    final completedCount = oneTimeCompleted.length;
    final next = nextScheduled;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        elevation: 1,
        color: context.theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dashboard_outlined, size: 18, color: context.theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Overview",
                    style: context.theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    avatar: Icon(Icons.schedule, size: 16, color: context.theme.colorScheme.primary),
                    label: Text("$pendingCount pending"),
                    backgroundColor: context.theme.colorScheme.primary.withValues(alpha: 0.1),
                    side: BorderSide(color: context.theme.colorScheme.primary.withValues(alpha: 0.4)),
                    labelStyle: TextStyle(
                      color: context.theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    avatar: const Icon(Icons.repeat, size: 16, color: Colors.teal),
                    label: Text("$recurringCount recurring"),
                    backgroundColor: Colors.teal.withValues(alpha: 0.1),
                    side: BorderSide(color: Colors.teal.withValues(alpha: 0.4)),
                    labelStyle: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                    label: Text("$completedCount completed"),
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    side: BorderSide(color: Colors.green.withValues(alpha: 0.4)),
                    labelStyle: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (next != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time_outlined, size: 13, color: context.theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      "Next: ${buildFullDate(next)}",
                      style: context.theme.textTheme.labelSmall?.copyWith(
                        color: context.theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ] else if (scheduled.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time_outlined, size: 13, color: context.theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      "No upcoming messages",
                      style: context.theme.textTheme.labelSmall?.copyWith(
                        color: context.theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem({
    required BuildContext context,
    required ScheduledMessage item,
    required IconData icon,
    required Color iconColor,
    required String subtitle,
    required bool isCompleted,
  }) {
    final chat = ChatsSvc.findChatByGuid(item.payload.chatGuid);
    final chatName = chat?.getTitle() ?? item.payload.chatGuid;

    return ListTile(
      key: ValueKey(item.id.toString()),
      mouseCursor: MouseCursor.defer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SettingsLeadingIcon(
        iosIcon: icon,
        materialIcon: icon,
        containerColor: iconColor,
      ),
      title: Text(
        item.payload.message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "→ $chatName",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.theme.textTheme.labelSmall?.copyWith(
              color: context.theme.colorScheme.outline,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.theme.textTheme.labelSmall?.copyWith(
              color: context.theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isCompleted) ...[
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 20, color: context.theme.colorScheme.primary),
              onPressed: () async {
                final result = await NavigationSvc.pushSettings(
                  context,
                  CreateScheduledMessage(existing: item),
                );
                if (result is ScheduledMessage) {
                  final idx = scheduled.indexWhere((e) => e.id == item.id);
                  scheduled[idx] = result;
                }
              },
            ),
          ],
          IconButton(
            icon: Icon(Icons.delete_outlined, size: 20, color: context.theme.colorScheme.error),
            onPressed: () => deleteMessage(item),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required List<ScheduledMessage> items,
    required IconData Function(ScheduledMessage) iconBuilder,
    required Color Function(ScheduledMessage) iconColorBuilder,
    required String Function(ScheduledMessage) subtitleBuilder,
    required bool isCompleted,
  }) {
    return SettingsSection(
      backgroundColor: tileColor,
      children: [
        Material(
          color: Colors.transparent,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            findChildIndexCallback: (key) => findChildIndexByKey(items, key, (item) => item.id.toString()),
            itemCount: items.length,
            separatorBuilder: (context, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildMessageItem(
                context: context,
                item: item,
                icon: iconBuilder(item),
                iconColor: iconColorBuilder(item),
                subtitle: subtitleBuilder(item),
                isCompleted: isCompleted,
              );
            },
          ),
        ),
      ],
    );
  }

  Color _iconColorForList(ScheduledMessage item, BuildContext context, Color defaultColor) {
    if (item.status == "error") return context.theme.colorScheme.error;
    return defaultColor;
  }

  IconData _iconForList(ScheduledMessage item) {
    if (item.status == "error") return Icons.error_outline;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SettingsScaffold(
        title: "Scheduled Messages",
        initialHeader: null,
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        fab: FloatingActionButton(
          backgroundColor: context.theme.colorScheme.primary,
          child: Icon(Icons.add, color: context.theme.colorScheme.onPrimary, size: 25),
          onPressed: () async {
            final result = await NavigationSvc.pushSettings(
              context,
              const CreateScheduledMessage(),
            );
            if (result is ScheduledMessage) {
              scheduled.add(result);
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: context.theme.colorScheme.onSurface),
            onPressed: () {
              fetching.value = true;
              scheduled.clear();
              getExistingMessages();
            },
          ),
        ],
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              // Empty / loading states
              if (fetching.value == null || fetching.value == true || (fetching.value == false && scheduled.isEmpty))
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Column(
                      children: [
                        Icon(
                          fetching.value == null
                              ? Icons.error_outline
                              : fetching.value == false
                                  ? Icons.event_busy_outlined
                                  : Icons.hourglass_empty_outlined,
                          size: 48,
                          color: context.theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          fetching.value == null
                              ? "Something went wrong!"
                              : fetching.value == false
                                  ? "No scheduled messages"
                                  : "Loading scheduled messages...",
                          style: context.theme.textTheme.labelLarge,
                        ),
                        if (fetching.value == true) ...[
                          const SizedBox(height: 16),
                          CircularProgressIndicator(
                            color: context.theme.colorScheme.primary,
                            strokeWidth: 2,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Stats header
              if (scheduled.isNotEmpty) _buildStatsHeader(context),

              // One-time pending
              if (oneTime.isNotEmpty)
                SettingsHeader(
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "One-Time Messages",
                ),
              if (oneTime.isNotEmpty)
                _buildSection(
                  items: oneTime,
                  iconBuilder: (_) => Icons.schedule,
                  iconColorBuilder: (_) => context.theme.colorScheme.primary,
                  subtitleBuilder: (item) => buildFullDate(item.scheduledFor),
                  isCompleted: false,
                ),

              // Recurring
              if (recurring.isNotEmpty)
                SettingsHeader(
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Recurring Messages",
                ),
              if (recurring.isNotEmpty)
                _buildSection(
                  items: recurring,
                  iconBuilder: (_) => Icons.repeat,
                  iconColorBuilder: (_) => Colors.teal,
                  subtitleBuilder: (item) =>
                      "Every ${item.schedule.interval} ${frequencyToText[item.schedule.intervalType]}(s) · ${buildFullDate(item.scheduledFor)}",
                  isCompleted: false,
                ),

              // Completed
              if (oneTimeCompleted.isNotEmpty)
                SettingsHeader(
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Completed Messages",
                ),
              if (oneTimeCompleted.isNotEmpty)
                _buildSection(
                  items: oneTimeCompleted,
                  iconBuilder: _iconForList,
                  iconColorBuilder: (item) => _iconColorForList(item, context, Colors.green),
                  subtitleBuilder: (item) {
                    if (item.status == "error") return item.error ?? "Failed to send";
                    return "Sent "
                        "${item.sentAt != null ? " · ${buildFullDate(item.sentAt!)}" : ""}";
                  },
                  isCompleted: true,
                ),
            ]),
          ),
        ],
      );
    });
  }
}
