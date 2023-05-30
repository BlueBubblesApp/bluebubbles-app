import 'package:bluebubbles/app/layouts/settings/pages/scheduling/create_scheduled_panel.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

class ScheduledMessagesPanel extends StatefulWidget {
  ScheduledMessagesPanel({
    Key? key,
  });

  @override
  State<ScheduledMessagesPanel> createState() => _ScheduledMessagesPanelState();
}

class _ScheduledMessagesPanelState extends OptimizedState<ScheduledMessagesPanel> {
  List<ScheduledMessage> scheduled = [];
  bool? fetching = true;

  @override
  void initState() {
    super.initState();
    getExistingMessages();
  }

  void getExistingMessages() async {
    final response = await http.getScheduled().catchError((_) {
      setState(() {
        fetching = null;
      });
      return Response(requestOptions: RequestOptions(path: ''));
    });
    if (response.statusCode == 200 && response.data['data'] != null) {
      scheduled = (response.data['data'] as List).map((e) => ScheduledMessage.fromJson(e)).toList().cast<ScheduledMessage>();
      setState(() {
        fetching = false;
      });
    }
  }

  void deleteMessage(ScheduledMessage item) async {
    final response = await http.deleteScheduled(item.id);
    if (response.statusCode == 200) {
      scheduled.remove(item);
      setState(() {});
    } else {
      Logger.error(response.data);
      showSnackbar("Error", "Something went wrong!");
    }
  }

  @override
  Widget build(BuildContext context) {
    final oneTime = scheduled.where((e) => e.schedule.type == "once" && e.status == "pending").toList();
    final oneTimeCompleted = scheduled.where((e) => e.schedule.type == "once" && e.status != "pending").toList();
    final recurring = scheduled.where((e) => e.schedule.type == "recurring").toList();
    return SettingsScaffold(
      title: "Scheduled Messages",
      initialHeader: fetching == false && scheduled.isNotEmpty ? "Info" : null,
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      fab: FloatingActionButton(
        backgroundColor: context.theme.colorScheme.primary,
        child: Icon(
          iOS ? CupertinoIcons.add : Icons.add,
          color: context.theme.colorScheme.onPrimary,
          size: 25
        ),
        onPressed: () async {
          final result = await ns.pushSettings(
            context,
            CreateScheduledMessage(),
          );
          if (result is ScheduledMessage) {
            scheduled.add(result);
            setState(() {});
          }
        },
      ),
      actions: [
        IconButton(
          icon: Icon(iOS ? CupertinoIcons.arrow_counterclockwise : Icons.refresh, color: context.theme.colorScheme.onBackground),
          onPressed: () {
            setState(() {
              fetching = true;
              scheduled.clear();
            });
            getExistingMessages();
          },
        ),
      ],
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            if (fetching == null || fetching == true || (fetching == false && scheduled.isEmpty))
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          fetching == null ? "Something went wrong!" : fetching == false ? "You have no scheduled messages." : "Getting scheduled messages...",
                          style: context.theme.textTheme.labelLarge,
                        ),
                      ),
                      if (fetching == true)
                        buildProgressIndicator(context, size: 15),
                    ],
                  ),
                ),
              ),
            if (scheduled.isNotEmpty)
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: SettingsSubtitle(
                      subtitle: "Tap to edit an existing scheduled message.\nOne-Time: Messages that will only be sent once at the displayed date.\nRecurring: Messages that will be sent on a recurring schedule.\nCompleted: One-time messages that have already been sent.",
                      unlimitedSpace: true,
                    ),
                  ),
                ],
              ),
            if (oneTime.isNotEmpty)
              SettingsHeader(
                headerColor: headerColor,
                tileColor: tileColor,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "One-Time Messages",
              ),
            if (oneTime.isNotEmpty)
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final item = oneTime[index];
                        final chat = chats.chats.firstWhereOrNull((e) => e.guid == item.payload.chatGuid);
                        return ListTile(
                          mouseCursor: SystemMouseCursors.click,
                          title: Text(item.payload.message),
                          subtitle: Text("Sending to ${chat == null ? item.payload.chatGuid : chat.getTitle()} on ${buildFullDate(item.scheduledFor)}"),
                          trailing: IconButton(
                            icon: Icon(iOS ? CupertinoIcons.trash : Icons.delete_outlined),
                            onPressed: () => deleteMessage(item),
                          ),
                          onTap: () async {
                            final result = await ns.pushSettings(
                              context,
                              CreateScheduledMessage(existing: item),
                            );
                            if (result is ScheduledMessage) {
                              final index = scheduled.indexWhere((e) => e.id == item.id);
                              scheduled[index] = result;
                              setState(() {});
                            }
                          },
                        );
                      },
                      itemCount: oneTime.length,
                    ),
                  ),
                ],
              ),
            if (recurring.isNotEmpty)
              SettingsHeader(
                headerColor: headerColor,
                tileColor: tileColor,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Recurring Messages",
              ),
            if (recurring.isNotEmpty)
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final item = recurring[index];
                        final chat = chats.chats.firstWhereOrNull((e) => e.guid == item.payload.chatGuid);
                        return ListTile(
                          mouseCursor: SystemMouseCursors.click,
                          title: Text(item.payload.message),
                          subtitle: Text("Sending to ${chat == null ? item.payload.chatGuid : chat.getTitle()} every ${item.schedule.interval} ${frequencyToText[item.schedule.intervalType]}(s) starting starting on ${buildFullDate(item.scheduledFor)}"),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: Icon(iOS ? CupertinoIcons.trash : Icons.delete_outlined),
                            onPressed: () => deleteMessage(item),
                          ),
                          onTap: () async {
                            final result = await ns.pushSettings(
                              context,
                              CreateScheduledMessage(existing: item),
                            );
                            if (result is ScheduledMessage) {
                              final index = scheduled.indexWhere((e) => e.id == item.id);
                              scheduled[index] = result;
                              setState(() {});
                            }
                          },
                        );
                      },
                      itemCount: recurring.length,
                    ),
                  ),
                ],
              ),
            if (oneTimeCompleted.isNotEmpty)
              SettingsHeader(
                headerColor: headerColor,
                tileColor: tileColor,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Completed Messages",
              ),
            if (oneTimeCompleted.isNotEmpty)
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final item = oneTimeCompleted[index];
                      final chat = chats.chats.firstWhereOrNull((e) => e.guid == item.payload.chatGuid);
                      return ListTile(
                        title: Text(item.payload.message),
                        subtitle: Text(item.status == "error"
                            ? item.error ?? "Something went wrong sending this message."
                            : "Sent to ${chat == null ? item.payload.chatGuid : chat.getTitle()}${item.sentAt != null ? " on ${buildFullDate(item.sentAt!)}" : ""}",
                          style: context.theme.textTheme.bodyMedium!.copyWith(color: item.status == "error" ? context.theme.colorScheme.error : null),
                        ),
                        trailing: IconButton(
                          icon: Icon(iOS ? CupertinoIcons.trash : Icons.delete_outlined),
                          onPressed: () => deleteMessage(item),
                        ),
                      );
                    },
                    itemCount: oneTimeCompleted.length,
                  ),
                ],
              ),
          ]),
        ),
      ]
    );
  }
}
