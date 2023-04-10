import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart' hide PlatformFile;
import 'package:bluebubbles/services/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:universal_io/io.dart';

class ConversationPanel extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _ConversationPanelState();
}

class _ConversationPanelState extends OptimizedState<ConversationPanel> {
  final RxnBool gettingIcons = RxnBool(null);

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Conversations",
      initialHeader: "Customization",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      ss.settings.showDeliveryTimestamps.value = val;
                      saveSettings();
                    },
                    initialVal: ss.settings.showDeliveryTimestamps.value,
                    title: "Show Delivery Timestamps",
                    backgroundColor: tileColor,
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      ss.settings.recipientAsPlaceholder.value = val;
                      saveSettings();
                    },
                    initialVal: ss.settings.recipientAsPlaceholder.value,
                    title: "Show Chat Name as Placeholder",
                    subtitle: "Changes the default hint text in the message box to display the recipient name",
                    backgroundColor: tileColor,
                    isThreeLine: true,
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      ss.settings.alwaysShowAvatars.value = val;
                      saveSettings();
                    },
                    initialVal: ss.settings.alwaysShowAvatars.value,
                    title: "Show Avatars in DM Chats",
                    subtitle: "Shows contact avatars in direct messages rather than just in group messages",
                    backgroundColor: tileColor,
                    isThreeLine: true,
                  )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        ss.settings.smartReply.value = val;
                        saveSettings();
                      },
                      initialVal: ss.settings.smartReply.value,
                      title: "Show Smart Replies",
                      subtitle: "Shows smart reply suggestions above the message text field",
                      backgroundColor: tileColor,
                      isThreeLine: true,
                    )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      ss.settings.repliesToPrevious.value = val;
                      saveSettings();
                    },
                    initialVal: ss.settings.repliesToPrevious.value,
                    title: "Show Replies To Previous Message",
                    subtitle: "Shows replies to the previous message in the thread rather than the original",
                    backgroundColor: tileColor,
                    isThreeLine: true,
                  )),
                  if (!kIsWeb)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb)
                    SettingsTile(
                      title: "Sync Group Chat Icons",
                      trailing: Obx(() => gettingIcons.value == null
                          ? const SizedBox.shrink()
                          : gettingIcons.value == true ? Container(
                          constraints: const BoxConstraints(
                            maxHeight: 20,
                            maxWidth: 20,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                          )) : Icon(Icons.check, color: context.theme.colorScheme.outline)
                      ),
                      onTap: () async {
                        gettingIcons.value = true;
                        for (Chat c in chats.chats.where((c) => c.isGroup)) {
                          await Chat.getIcon(c, force: true);
                        }
                        gettingIcons.value = false;
                      },
                      subtitle: "Get iMessage group chat icons from the server",
                    ),
                  if (!kIsWeb)
                    const SettingsSubtitle(
                      subtitle: "Note: Overrides any custom avatars set for group chats.",
                    ),
                  if (!kIsWeb)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        ss.settings.scrollToLastUnread.value = val;
                        saveSettings();
                      },
                      initialVal: ss.settings.scrollToLastUnread.value,
                      title: "Store Last Read Message",
                      subtitle: "Remembers the last opened message and allows automatically scrolling back to it if out of view",
                      backgroundColor: tileColor,
                      isThreeLine: true,
                    )),
                  if (!kIsWeb)
                    const SettingsSubtitle(
                      subtitle: "Note: Can result in degraded performance depending on how many unread messages there are.",
                    ),
                  if (!kIsWeb)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb)
                    SettingsTile(
                      title: "User Profile",
                      onTap: () async {
                        final nameController = TextEditingController(text: ss.settings.userName.value);
                        await showDialog(
                            context: context,
                            builder: (_) {
                              return AlertDialog(
                                actions: [
                                  TextButton(
                                    child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () => Get.back(),
                                  ),
                                  TextButton(
                                    child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () async {
                                      if (nameController.text.isEmpty) {
                                        showSnackbar("Error", "Enter a name!");
                                        return;
                                      }
                                      Get.back();
                                      ss.settings.userName.value = nameController.text;
                                      ss.settings.save();
                                    },
                                  ),
                                ],
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(Get.context!).push(
                                          ThemeSwitcher.buildPageRoute(
                                            builder: (context) => AvatarCrop(),
                                          ),
                                        );
                                      },
                                      child: ContactAvatarWidget(
                                        handle: null,
                                        borderThickness: 0.1,
                                        editable: false,
                                        fontSize: 22,
                                        size: 60,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: nameController,
                                      decoration: const InputDecoration(
                                        labelText: "Name",
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text("User Profile", style: context.theme.textTheme.titleLarge),
                                backgroundColor: context.theme.colorScheme.properSurface,
                              );
                            }
                        );
                      },
                      subtitle: "Set a name and avatar for yourself",
                    ),
                ],
              ),
              if (!kIsWeb)
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Sounds"),
              if (!kIsWeb)
                Obx(() => SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    if (ss.settings.sendSoundPath.value == null)
                      SettingsTile(
                        title: "Add Send Sound",
                        subtitle: "Adds a sound to be played when sending a message",
                        onTap: () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
                          if (result != null) {
                            PlatformFile platformFile = result.files.first;
                            String path = "${fs.appDocDir.path}/sounds/${"send-"}${platformFile.name}";
                            await File(path).create(recursive: true);
                            await File(path).writeAsBytes(platformFile.bytes!);
                            ss.settings.sendSoundPath.value = path;
                            ss.saveSettings();
                          }
                        },
                      ),
                    if (ss.settings.sendSoundPath.value != null)
                      SettingsTile(
                        title: "Delete Send Sound",
                        onTap: () async {
                          File file = File(ss.settings.sendSoundPath.value!);
                          if (await file.exists()) {
                            await file.delete();
                          }
                          ss.settings.sendSoundPath.value = null;
                          ss.saveSettings();
                        },
                      ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                    if (ss.settings.receiveSoundPath.value == null)
                      SettingsTile(
                        title: "Add Receive Sound",
                        subtitle: "Adds a sound to be played when receiving a message",
                        onTap: () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
                          if (result != null) {
                            PlatformFile platformFile = result.files.first;
                            String path = "${fs.appDocDir.path}/sounds/${"receive-"}${platformFile.name}";
                            await File(path).create(recursive: true);
                            await File(path).writeAsBytes(platformFile.bytes!);
                            ss.settings.receiveSoundPath.value = path;
                            ss.saveSettings();
                          }
                        },
                      ),
                    if (ss.settings.receiveSoundPath.value != null)
                      SettingsTile(
                        title: "Delete Receive Sound",
                        onTap: () async {
                          File file = File(ss.settings.receiveSoundPath.value!);
                          if (await file.exists()) {
                            await file.delete();
                          }
                          ss.settings.receiveSoundPath.value = null;
                          ss.saveSettings();
                        },
                      ),
                  ]
                )),
              SettingsHeader(
                  headerColor: headerColor,
                  tileColor: tileColor,
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Gestures"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        ss.settings.autoOpenKeyboard.value = val;
                        saveSettings();
                      },
                      initialVal: ss.settings.autoOpenKeyboard.value,
                      title: "Auto-open Keyboard",
                      subtitle: "Automatically open the keyboard when entering a chat",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        ss.settings.swipeToCloseKeyboard.value = val;
                        saveSettings();
                      },
                      initialVal: ss.settings.swipeToCloseKeyboard.value,
                      title: "Swipe Message Box to Close Keyboard",
                      subtitle: "Swipe down on the message box to hide the keyboard",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        ss.settings.swipeToOpenKeyboard.value = val;
                        saveSettings();
                      },
                      initialVal: ss.settings.swipeToOpenKeyboard.value,
                      title: "Swipe Message Box to Open Keyboard",
                      subtitle: "Swipe up on the message box to show the keyboard",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        ss.settings.hideKeyboardOnScroll.value = val;
                        saveSettings();
                      },
                      initialVal: ss.settings.hideKeyboardOnScroll.value,
                      title: "Hide Keyboard When Scrolling",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        ss.settings.openKeyboardOnSTB.value = val;
                        saveSettings();
                      },
                      initialVal: ss.settings.openKeyboardOnSTB.value,
                      title: "Open Keyboard After Tapping Scroll To Bottom",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      ss.settings.doubleTapForDetails.value = val;
                      if (val && ss.settings.enableQuickTapback.value) {
                        ss.settings.enableQuickTapback.value = false;
                      }
                      saveSettings();
                    },
                    initialVal: ss.settings.doubleTapForDetails.value,
                    title: "Double-${kIsWeb || kIsDesktop ? "Click" : "Tap"} Message for Details",
                    subtitle: "Opens the message details popup when double ${kIsWeb || kIsDesktop ? "click" : "tapp"}ing a message",
                    backgroundColor: tileColor,
                    isThreeLine: true,
                  )),
                  if (!kIsDesktop && !kIsWeb)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsDesktop && !kIsWeb)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        ss.settings.sendWithReturn.value = val;
                        saveSettings();
                      },
                      initialVal: ss.settings.sendWithReturn.value,
                      title: "Send Message with Enter",
                      backgroundColor: tileColor,
                    )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      ss.settings.scrollToBottomOnSend.value = val;
                      saveSettings();
                    },
                    initialVal: ss.settings.scrollToBottomOnSend.value,
                    title: "Scroll To Bottom When Sending Messages",
                    subtitle: "Scroll to the most recent messages in the chat when sending a new text",
                    backgroundColor: tileColor,
                  )),
                ],
              ),
            ],
          ),
        ),
      ]
    );
  }

  void saveSettings() {
    ss.saveSettings();
  }
}
