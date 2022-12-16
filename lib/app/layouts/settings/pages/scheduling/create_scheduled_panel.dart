import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/components/custom/custom_cupertino_text_field.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:numberpicker/numberpicker.dart';

class CreateScheduledMessage extends StatefulWidget {
  CreateScheduledMessage({
    Key? key,
    this.existing,
  });

  final ScheduledMessage? existing;

  @override
  State<CreateScheduledMessage> createState() => _CreateScheduledMessageState();
}

class _CreateScheduledMessageState extends OptimizedState<CreateScheduledMessage> {
  final TextEditingController messageController = TextEditingController();
  final FocusNode messageNode = FocusNode();

  late String selectedChat = widget.existing?.payload.chatGuid ?? chats.chats.first.guid;
  late String schedule = widget.existing?.schedule.type ?? "once";
  late String frequency = widget.existing?.schedule.intervalType ?? "daily";
  late int interval = widget.existing?.schedule.interval ?? 1;
  late DateTime date = widget.existing?.scheduledFor ?? DateTime.now();
  bool isEmpty = true;

  @override
  void initState() {
    super.initState();
     messageController.addListener(() {
       if (messageController.text.isEmpty && !isEmpty) {
         isEmpty = true;
         setState(() {});
       } else if (isEmpty) {
         isEmpty = false;
         setState(() {});
       }
     });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: widget.existing != null ? "Edit Existing" : "Create New",
      initialHeader: "Message Info",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      fab: isEmpty || date.isBefore(DateTime.now()) ? null : FloatingActionButton(
        backgroundColor: context.theme.colorScheme.primary,
        child: Icon(
            iOS ? CupertinoIcons.check_mark : Icons.done,
            color: context.theme.colorScheme.onPrimary,
            size: 25
        ),
        onPressed: () async {
          if (date.isBefore(DateTime.now())) return showSnackbar("Error", "Pick a date in the future!");
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: context.theme.colorScheme.properSurface,
                title: Text(
                  "Scheduling message...",
                  style: context.theme.textTheme.titleLarge,
                ),
                content: Container(
                  height: 70,
                  child: Center(
                    child: CircularProgressIndicator(
                      backgroundColor: context.theme.colorScheme.properSurface,
                      valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                    ),
                  ),
                ),
              );
            }
          );
          Response? response;
          if (widget.existing == null) {
            response = await http.createScheduled(selectedChat, messageController.text, date.toUtc(), schedule == "once" ? {
              "type": "once",
            } : {
              "type": "recurring",
              "interval": interval,
              "intervalType": frequency,
            });
          } else {
            response = await http.createScheduled(selectedChat, messageController.text, date.toUtc(), schedule == "once" ? {
              "type": "once",
            } : {
              "type": "recurring",
              "interval": interval,
              "intervalType": frequency,
            });
          }
          Navigator.of(context).pop();
          if (response.statusCode == 200 && response.data != null) {
            final message = ScheduledMessage.fromJson(response.data['data']);
            Navigator.of(context).pop(message);
          } else {
            Logger.error("Scheduled message error: ${response.statusCode}");
            Logger.error(response.data);
            showSnackbar("Error", "Something went wrong!");
          }
        },
      ),
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                SettingsOptions<Chat>(
                  initial: chats.chats.firstWhere((e) => e.guid == selectedChat),
                  options: chats.chats,
                  onChanged: (Chat? val) {
                    if (val == null) return;
                    setState(() {
                      selectedChat = val.guid;
                    });
                  },
                  title: "Select Chat",
                  backgroundColor: tileColor,
                  secondaryColor: headerColor,
                  textProcessing: (val) => val.toString(),
                  useCupertino: false,
                  clampWidth: false,
                  materialCustomWidgets: (chat) => Row(
                    children: [
                      ContactAvatarGroupWidget(
                        chat: chat,
                        size: 35,
                        editable: false,
                        onTap: () {},
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: Text(
                            chat.getTitle(),
                            style: context.theme.textTheme.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: CustomCupertinoTextField(
                    textCapitalization: TextCapitalization.sentences,
                    focusNode: messageNode,
                    autocorrect: true,
                    controller: messageController,
                    style: context.theme.extension<BubbleText>()!.bubbleText,
                    keyboardType: TextInputType.multiline,
                    maxLines: 14,
                    minLines: 1,
                    placeholder: "Message",
                    padding: EdgeInsets.all(iOS ? 10 : 12.5),
                    placeholderStyle: context.theme.extension<BubbleText>()!.bubbleText.copyWith(color: context.theme.colorScheme.outline),
                    selectionControls: ss.settings.skin.value == Skins.iOS ? cupertinoTextSelectionControls : materialTextSelectionControls,
                    enableIMEPersonalizedLearning: !ss.settings.incognitoKeyboard.value,
                    textInputAction: TextInputAction.done,
                    cursorColor: context.theme.colorScheme.primary,
                    cursorHeight: context.theme.extension<BubbleText>()!.bubbleText.fontSize! * 1.25,
                    decoration: BoxDecoration(
                      border: Border.all(color: context.theme.colorScheme.outline),
                      borderRadius: BorderRadius.all(Radius.circular(samsung ? 25 : 10)),
                    ),
                    onLongPressStart: () {
                      Feedback.forLongPress(context);
                    },
                    onTap: () {
                      HapticFeedback.selectionClick();
                    },
                    onSubmitted: (String value) {
                      messageNode.unfocus();
                    },
                  ),
                ),
              ]
            ),
            SettingsHeader(
              headerColor: headerColor,
              tileColor: tileColor,
              iosSubtitle: iosSubtitle,
              materialSubtitle: materialSubtitle,
              text: "Schedule",
            ),
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                SettingsOptions<String>(
                  initial: schedule,
                  options: ["once", "recurring"],
                  onChanged: (String? val) {
                    if (val == null) return;
                    setState(() {
                      schedule = val;
                    });
                  },
                  title: "Schedule",
                  backgroundColor: tileColor,
                  secondaryColor: headerColor,
                  textProcessing: (val) => val.capitalizeFirst!,
                ),
                AnimatedSizeAndFade.showHide(
                  show: schedule == "recurring",
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 15.0),
                            child: Text("Repeat every:", style: context.theme.textTheme.bodyLarge!),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15.0),
                              child: NumberPicker(
                                value: interval,
                                minValue: 1,
                                maxValue: 100,
                                itemWidth: 50,
                                haptics: true,
                                axis: Axis.horizontal,
                                textStyle: context.theme.textTheme.bodyLarge!,
                                selectedTextStyle: context.theme.textTheme.headlineMedium!.copyWith(color: context.theme.colorScheme.primary),
                                onChanged: (value) => setState(() => interval = value),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5.0),
                        child: SettingsOptions<String>(
                          title: "With frequency:",
                          options: ["daily", "weekly", "monthly", "yearly"],
                          initial: frequency,
                          textProcessing: (val) => "${frequencyToText[val]!.capitalizeFirst!}${interval == 1 ? "" : "s"}",
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              frequency = val;
                            });
                          },
                          backgroundColor: tileColor,
                          secondaryColor: headerColor,
                        ),
                      ),
                    ]
                  ),
                ),
                SettingsTile(
                  title: "Pick date and time",
                  subtitle: "Current: ${buildSeparatorDateSamsung(date)} at ${buildTime(date)}",
                  onTap: () async {
                    final newDate = await showTimeframePicker("Pick date and time", context, presetsAhead: true);
                    if (newDate == null) return;
                    if (newDate.isBefore(DateTime.now())) return showSnackbar("Error", "Pick a date in the future!");
                    setState(() {
                      date = newDate;
                    });
                  },
                ),
              ],
            ),
            SettingsHeader(
              headerColor: headerColor,
              tileColor: tileColor,
              iosSubtitle: iosSubtitle,
              materialSubtitle: materialSubtitle,
              text: "Summary",
            ),
            SettingsSection(
              backgroundColor: tileColor,
              children: [
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: ValueListenableBuilder(
                    valueListenable: messageController,
                    builder: (context, value, _) {
                      return Text("Scheduling \"${messageController.text}\" to ${chats.chats.firstWhere((e) => e.guid == selectedChat).getTitle()}.\nScheduling $schedule${schedule == "recurring" ? " every $interval ${frequencyToText[frequency]}(s) starting" : ""} on ${buildSeparatorDateSamsung(date)} at ${buildTime(date)}.");
                    },
                  ),
                ),
              ],
            ),
          ]),
        ),
      ],
    );
  }
}
