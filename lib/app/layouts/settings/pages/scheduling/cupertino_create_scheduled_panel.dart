import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/layouts/chat_selector_view/chat_selector_view.dart';
import 'package:bluebubbles/app/layouts/settings/pages/scheduling/create_scheduled_mixin.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:numberpicker/numberpicker.dart';

class CupertinoCreateScheduledMessage extends StatefulWidget {
  const CupertinoCreateScheduledMessage({super.key, this.existing});

  final ScheduledMessage? existing;

  @override
  State<CupertinoCreateScheduledMessage> createState() => _CupertinoCreateScheduledMessageState();
}

class _CupertinoCreateScheduledMessageState extends State<CupertinoCreateScheduledMessage>
    with ThemeHelpers, CreateScheduledMixin {
  @override
  ScheduledMessage? get existingMessage => widget.existing;

  @override
  void initState() {
    super.initState();
    initForm();
  }

  Future<void> _pickDateTime(BuildContext context) async {
    DateTime picked = date.value;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: ctx.theme.colorScheme.surfaceContainerHighest,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: Text("Cancel", style: TextStyle(color: ctx.theme.colorScheme.outline)),
                  onPressed: () => Navigator.pop(ctx),
                ),
                CupertinoButton(
                  child: Text("Done", style: TextStyle(color: ctx.theme.colorScheme.primary)),
                  onPressed: () {
                    if (picked.isBefore(DateTime.now())) {
                      showSnackbar("Error", "Pick a date in the future!");
                    } else {
                      date.value = picked;
                    }
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime:
                    date.value.isAfter(DateTime.now()) ? date.value : DateTime.now().add(const Duration(minutes: 1)),
                minimumDate: DateTime.now(),
                mode: CupertinoDatePickerMode.dateAndTime,
                onDateTimeChanged: (dt) => picked = dt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final error = validationError;

      return SettingsScaffold(
        title: widget.existing != null ? "Edit Message" : "New Message",
        initialHeader: "Message Info",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        fab: error != null
            ? null
            : FloatingActionButton(
                backgroundColor: context.theme.colorScheme.primary,
                child: Icon(CupertinoIcons.check_mark, color: context.theme.colorScheme.onPrimary, size: 25),
                onPressed: () => saveScheduledMessage(context),
              ),
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              // Message Info section
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  SettingsTile(
                    title: "Chat",
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.chat_bubble_2_fill,
                      materialIcon: CupertinoIcons.chat_bubble_2_fill,
                      containerColor: context.theme.colorScheme.primary,
                    ),
                    trailing: Obx(() {
                      final chat = selectedChat.value.isEmpty ? null : ChatsSvc.findChatByGuid(selectedChat.value);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (chat != null) ...[
                            ContactAvatarGroupWidget(chat: chat, size: 28, editable: false),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                chat.getTitle(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.theme.textTheme.bodyMedium?.copyWith(
                                  color: context.theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ] else
                            Text(
                              "Select a chat",
                              style: context.theme.textTheme.bodyMedium?.copyWith(
                                color: context.theme.colorScheme.error,
                              ),
                            ),
                          Icon(CupertinoIcons.chevron_right, size: 14, color: context.theme.colorScheme.outline),
                        ],
                      );
                    }),
                    onTap: () {
                      NavigationSvc.push(
                        context,
                        ChatSelectorView(
                          onSelect: (chat) {
                            selectedChat.value = chat.guid;
                          },
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 4, 15, 15),
                    child: buildMessageTextField(context, borderRadius: 10),
                  ),
                ],
              ),

              // Schedule section
              SettingsHeader(
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Schedule",
              ),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  // Schedule type segmented control
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Obx(() => CupertinoSlidingSegmentedControl<String>(
                          groupValue: schedule.value,
                          children: {
                            "once": Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.calendar, size: 16),
                                  const SizedBox(width: 4),
                                  Text("Once", style: context.theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            "recurring": Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.arrow_clockwise, size: 16),
                                  const SizedBox(width: 4),
                                  Text("Recurring", style: context.theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          },
                          onValueChanged: (val) {
                            if (val != null) schedule.value = val;
                          },
                        )),
                  ),

                  // Recurring options
                  AnimatedSizeAndFade.showHide(
                    show: schedule.value == "recurring",
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          child: Row(
                            children: [
                              Text("Repeat every:", style: context.theme.textTheme.bodyLarge),
                              if (kIsWeb || kIsDesktop) const Spacer(),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: kIsWeb || kIsDesktop
                                      ? TextField(
                                          controller: numberController,
                                          decoration: const InputDecoration(
                                            labelText: "1-100",
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        )
                                      : NumberPicker(
                                          value: repeatInterval.value,
                                          minValue: 1,
                                          maxValue: 100,
                                          itemWidth: 50,
                                          haptics: true,
                                          axis: Axis.horizontal,
                                          textStyle: context.theme.textTheme.bodyLarge!,
                                          selectedTextStyle: context.theme.textTheme.headlineMedium!
                                              .copyWith(color: context.theme.colorScheme.primary),
                                          onChanged: (value) => repeatInterval.value = value,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SettingsOptions<String>(
                            title: "With frequency:",
                            options: const ["hourly", "daily", "weekly", "monthly", "yearly"],
                            initial: frequency.value,
                            textProcessing: (val) =>
                                "${frequencyToText[val]!.capitalizeFirst!}${repeatInterval.value == 1 ? "" : "s"}",
                            onChanged: (val) {
                              if (val != null) frequency.value = val;
                            },
                            secondaryColor: headerColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Date/time picker tile
                  SettingsTile(
                    title: "Date & Time",
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.calendar,
                      materialIcon: CupertinoIcons.calendar,
                      containerColor: Colors.orange,
                    ),
                    subtitle: "${buildSeparatorDateSamsung(date.value)} at ${buildTime(date.value)}",
                    onTap: () => _pickDateTime(context),
                    trailing: Icon(CupertinoIcons.chevron_right, size: 14, color: context.theme.colorScheme.outline),
                  ),
                ],
              ),

              // Summary section
              SettingsHeader(
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Summary",
              ),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: ValueListenableBuilder(
                      valueListenable: messageController,
                      builder: (context, _, _) {
                        if (error != null) return Text(error, style: const TextStyle(color: Colors.red));
                        final chat = ChatsSvc.findChatByGuid(selectedChat.value);
                        return Text(
                          "Scheduling \"${messageController.text}\" to ${chat?.getTitle() ?? selectedChat.value}.\n"
                          "Sending ${schedule.value == "recurring" ? "every ${repeatInterval.value} ${frequencyToText[frequency.value]}(s) starting" : "once"} on "
                          "${buildSeparatorDateSamsung(date.value)} at ${buildTime(date.value)}.",
                          style: context.theme.textTheme.bodyMedium,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ],
      );
    });
  }
}
