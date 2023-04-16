import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart' hide Response;

class MessageRemindersPanel extends StatefulWidget {
  MessageRemindersPanel({
    Key? key,
  });

  @override
  State<MessageRemindersPanel> createState() => _MessageRemindersPanelState();
}

class _MessageRemindersPanelState extends OptimizedState<MessageRemindersPanel> {
  List<PendingNotificationRequest> scheduled = [];
  bool? fetching = true;

  @override
  void initState() {
    super.initState();
    getExistingMessages();
  }

  void getExistingMessages() async {
    final _pending = await notif.flnp.pendingNotificationRequests();
    setState(() {
      scheduled = _pending;
      fetching = false;
    });
  }

  void deleteMessage(PendingNotificationRequest item) async {
    setState(() {
      scheduled.removeWhere((element) => element.id == item.id);
    });
    notif.flnp.cancel(item.id);
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
                        if (fetching == true)
                          buildProgressIndicator(context, size: 15),
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
                      itemBuilder: (context, index) {
                        final item = scheduled[index];
                        return ListTile(
                          mouseCursor: SystemMouseCursors.click,
                          title: Text(item.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: int.tryParse(item.payload!) == null
                              ? Text(item.title!.replaceAll("Reminder: ", ""))
                              : Text("${item.title!.replaceAll("Reminder: ", "")}\n${buildFullDate(DateTime.fromMillisecondsSinceEpoch(int.parse(item.payload!)))}"),
                          isThreeLine: int.tryParse(item.payload!) == null ? false : true,
                          onTap: () async {
                            final finalDate = await showTimeframePicker("Select Reminder Time", context, presetsAhead: true);
                            if (finalDate != null) {
                              if (!finalDate.isAfter(DateTime.now().toLocal())) {
                                showSnackbar("Error", "Select a date in the future");
                                return;
                              }
                              deleteMessage(item);
                              await notif.createReminder(null, null, finalDate, chatTitle: item.title, messageText: item.body);
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
        ]
    );
  }
}
