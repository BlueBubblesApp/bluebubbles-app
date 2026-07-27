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
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:numberpicker/numberpicker.dart';

class MaterialCreateScheduledMessage extends StatefulWidget {
  const MaterialCreateScheduledMessage({super.key, this.existing});

  final ScheduledMessage? existing;

  @override
  State<MaterialCreateScheduledMessage> createState() => _MaterialCreateScheduledMessageState();
}

class _MaterialCreateScheduledMessageState extends State<MaterialCreateScheduledMessage>
    with ThemeHelpers, CreateScheduledMixin {
  @override
  ScheduledMessage? get existingMessage => widget.existing;

  @override
  void initState() {
    super.initState();
    initForm();
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: date.value.isAfter(DateTime.now()) ? date.value : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date.value),
    );
    if (pickedTime == null) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (combined.isBefore(DateTime.now())) {
      showSnackbar("Error", "Pick a date in the future!");
      return;
    }

    date.value = combined;
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
                child: Icon(Icons.done, color: context.theme.colorScheme.onPrimary, size: 25),
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
                    padding: const EdgeInsets.all(15.0),
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
                  // Schedule type — Material 3 SegmentedButton
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Obx(() => SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: "once",
                              icon: Icon(Icons.calendar_today_outlined, size: 16),
                              label: Text("Once"),
                            ),
                            ButtonSegment(
                              value: "recurring",
                              icon: Icon(Icons.repeat, size: 16),
                              label: Text("Recurring"),
                            ),
                          ],
                          selected: {schedule.value},
                          onSelectionChanged: (val) {
                            schedule.value = val.first;
                          },
                          style: ButtonStyle(
                            side: WidgetStatePropertyAll(
                              BorderSide(color: context.theme.colorScheme.outline.withValues(alpha: 0.5)),
                            ),
                          ),
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
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 5),
                                          child: TextField(
                                            controller: numberController,
                                            decoration: const InputDecoration(
                                              labelText: "1-100",
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                RegExp(r'^[1-9]\d?$|^100$|^$'),
                                                replacementString: numberController.text,
                                              ),
                                            ],
                                          ),
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
                      iosIcon: Icons.calendar_month_outlined,
                      materialIcon: Icons.calendar_month_outlined,
                      containerColor: Colors.orange,
                    ),
                    subtitle: "${buildSeparatorDateSamsung(date.value)} at ${buildTime(date.value)}",
                    onTap: () => _pickDateTime(context),
                    trailing: Icon(Icons.chevron_right, color: context.theme.colorScheme.outline),
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
                  Obx(() => Padding(
                        padding: const EdgeInsets.all(15),
                        child: ValueListenableBuilder(
                          valueListenable: messageController,
                          builder: (context, _, __) {
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
                      )),
                ],
              ),
            ]),
          ),
        ],
      );
    });
  }
}
