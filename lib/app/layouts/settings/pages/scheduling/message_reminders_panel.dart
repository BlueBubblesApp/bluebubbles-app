import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/notifications/desktop_notification.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart' hide Response;
import 'package:universal_io/io.dart';

class MessageRemindersPanel extends StatefulWidget {
  const MessageRemindersPanel({super.key});

  @override
  State<MessageRemindersPanel> createState() => _MessageRemindersPanelState();
}

class _MessageRemindersPanelState extends State<MessageRemindersPanel> with ThemeHelpers {
  List<PendingNotificationRequest> scheduled = [];
  bool? fetching = true;

  @override
  void initState() {
    super.initState();
    getExistingMessages();
  }

  void getExistingMessages() async {
    // Windows schedules through the desktop plugin, which also holds other scheduled toasts.
    final _pending = Platform.isWindows
        ? (await DesktopNotifications.pendingRequests()).where((r) => NotificationsService.isReminderId(r.id)).toList()
        : await NotificationsSvc.flnp.pendingNotificationRequests();
    setState(() {
      scheduled = _pending;
      fetching = false;
    });
  }

  void deleteMessage(PendingNotificationRequest item) async {
    setState(() {
      scheduled.removeWhere((element) => element.id == item.id);
    });
    if (Platform.isWindows) {
      await DesktopNotifications.cancel(item.id);
    } else {
      await NotificationsSvc.flnp.cancel(id: item.id);
    }
  }

  /// Android reminders carry their time in the payload; Windows reads it from the OS schedule.
  DateTime? _reminderTime(PendingNotificationRequest item) {
    if (item is WindowsPendingNotificationRequest) return item.scheduledDate;
    final int? millis = int.tryParse(item.payload ?? '');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
        title: "Message Reminders",
        initialHeader: null,
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              if (fetching == true || (fetching == false && scheduled.isEmpty))
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            fetching == false ? "You have no message reminders." : "Getting message reminders...",
                            style: context.theme.textTheme.labelLarge,
                          ),
                        ),
                        if (fetching == true) buildProgressIndicator(context, size: 15),
                      ],
                    ),
                  ),
                ),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      findChildIndexCallback: (key) =>
                          findChildIndexByKey(scheduled, key, (item) => item.id.toString()),
                      itemBuilder: (context, index) {
                        final item = scheduled[index];
                        final chatTitle = (item.title ?? "").replaceAll("Reminder: ", "");
                        final time = _reminderTime(item);
                        return ListTile(
                          key: ValueKey(item.id.toString()),
                          mouseCursor: MouseCursor.defer,
                          title: Text(item.body ?? "", maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(time == null ? chatTitle : "$chatTitle\n${buildFullDate(time)}"),
                          isThreeLine: time != null,
                          onTap: () async {
                            final finalDate = await showTimeframePicker("Select Reminder Time", context,
                                presetsAhead: true,
                                additionalTimeframes: {
                                  "3 Hours": 3,
                                  "6 Hours": 6,
                                },
                                useTodayYesterday: true);
                            if (finalDate != null) {
                              if (!finalDate.isAfter(DateTime.now().toLocal())) {
                                showSnackbar("Error", "Select a date in the future", type: SnackbarType.error);
                                return;
                              }
                              deleteMessage(item);
                              // Windows reminders link to their chat through the payload; keep that and the avatar.
                              final chatGuid = item is WindowsPendingNotificationRequest
                                  ? DesktopMessageData.fromPayload(item.payload ?? '')?.chatGuid
                                  : null;
                              await NotificationsSvc.createReminder(
                                  chatGuid == null ? null : Chat.findOne(guid: chatGuid), null, finalDate,
                                  chatTitle: item.title, messageText: item.body);
                              showSnackbar("Notice", "Scheduled reminder for ${buildDate(finalDate)}");
                              getExistingMessages();
                            }
                          },
                          trailing: IconButton(
                            icon: Icon(iOS ? CupertinoIcons.trash : Icons.delete_outlined),
                            onPressed: () => deleteMessage(item),
                          ),
                        );
                      },
                      itemCount: scheduled.length,
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ]);
  }
}
