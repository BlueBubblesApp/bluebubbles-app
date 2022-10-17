import 'dart:math';

import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RedactedModePanel extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _RedactedModePanelState();
}

class _RedactedModePanelState extends OptimizedState<RedactedModePanel> with ThemeHelpers {

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: "Redacted Mode",
      initialHeader: "Redacted Mode",
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
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                    child: Text(
                        "Redacted Mode hides your personal information, such as contact names, message content, and more. This is useful when taking screenshots to send to developers."
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10),
                child: AbsorbPointer(
                  absorbing: true,
                  child: MessageWidget(
                    newerMessage: null,
                    olderMessage: null,
                    isFirstSentMessage: false,
                    showHandle: true,
                    showHero: false,
                    showReplies: false,
                    autoplayEffect: false,
                    message: Message(
                      guid: "redacted-mode-demo",
                      dateDelivered2: DateTime.now().toLocal(),
                      dateCreated: DateTime.now().toLocal(),
                      isFromMe: false,
                      hasReactions: true,
                      hasAttachments: true,
                      text: "This is a preview of Redacted Mode settings.",
                      handle: Handle(
                        id: Random.secure().nextInt(10000),
                        address: "John Doe",
                      ),
                      associatedMessages: [
                        Message(
                          dateCreated: DateTime.now().toLocal(),
                          guid: "redacted-mode-demo",
                          text: "Jane Doe liked a message you sent",
                          associatedMessageType: "like",
                          isFromMe: true,
                        ),
                      ],
                      attachments: [
                        Attachment(
                          guid: "redacted-mode-demo-attachment",
                          originalROWID: Random.secure().nextInt(10000),
                          transferName: "assets/icon/icon.png",
                          mimeType: "image/png",
                          width: 100,
                          height: 100,
                        )
                      ],
                    ),
                  ),
                ),
              ),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      ss.settings.redactedMode.value = val;
                      saveSettings();
                    },
                    initialVal: ss.settings.redactedMode.value,
                    title: "Enable Redacted Mode",
                    backgroundColor: tileColor,
                  )),
                ],
              ),
              Obx(() => AnimatedSizeAndFade.showHide(
                show: ss.settings.redactedMode.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Hide Content"
                    ),
                    SettingsSection(
                      backgroundColor: tileColor,
                      children: [
                        SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.hideMessageContent.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.hideMessageContent.value,
                          title: "Hide Message Content",
                          backgroundColor: tileColor,
                          subtitle: "Removes any trace of message text",
                        ),
                        Container(
                          color: tileColor,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 15.0),
                            child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                          ),
                        ),
                        SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.hideReactions.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.hideReactions.value,
                          title: "Hide Reactions",
                          backgroundColor: tileColor,
                          subtitle: "Removes any trace of reactions from messages",
                        ),
                      ],
                    ),
                    SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Hide Emojis & Attachments",
                    ),
                    SettingsSection(
                      backgroundColor: tileColor,
                      children: [
                        SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.hideEmojis.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.hideEmojis.value,
                          title: "Hide Big Emojis",
                          backgroundColor: tileColor,
                          subtitle: "Replaces large emojis with placeholder boxes",
                        ),
                        Container(
                          color: tileColor,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 15.0),
                            child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                          ),
                        ),
                        SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.hideAttachments.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.hideAttachments.value,
                          title: "Hide Attachments",
                          backgroundColor: tileColor,
                          subtitle: "Replaces attachments with placeholder boxes",
                        ),
                        Container(
                          color: tileColor,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 15.0),
                            child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                          ),
                        ),
                        SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.hideAttachmentTypes.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.hideAttachmentTypes.value,
                          title: "Hide Attachment Types",
                          backgroundColor: tileColor,
                          subtitle: "Removes the attachment file type text from the placeholder box",
                          isThreeLine: true,
                        ),
                      ],
                    ),
                    SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Hide Contact Info"
                    ),
                    SettingsSection(
                      backgroundColor: tileColor,
                      children: [
                        SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.hideContactPhotos.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.hideContactPhotos.value,
                          title: "Hide Contact Photos",
                          backgroundColor: tileColor,
                          subtitle: "Replaces message bubbles with empty bubbles",
                        ),
                        Container(
                          color: tileColor,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 15.0),
                            child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                          ),
                        ),
                        SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.hideContactInfo.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.hideContactInfo.value,
                          title: "Hide Contact Info",
                          backgroundColor: tileColor,
                          subtitle: "Removes any trace of contact names, numbers, and emails",
                          isThreeLine: true,
                        ),
                        Container(
                          color: tileColor,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 15.0),
                            child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                          ),
                        ),
                        SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.removeLetterAvatars.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.removeLetterAvatars.value,
                          title: "Remove Letter Avatars",
                          backgroundColor: tileColor,
                          subtitle: "Replaces letter avatars with generic person avatars",
                        ),
                      ],
                    ),
                    SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Generate Fake Info"
                    ),
                    SettingsSection(
                      backgroundColor: tileColor,
                      children: [
                        SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.generateFakeContactNames.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.generateFakeContactNames.value,
                          title: "Generate Fake Contact Names",
                          backgroundColor: tileColor,
                          subtitle: "Replaces contact names, numbers, and emails with auto-generated fake names",
                          isThreeLine: true,
                        ),
                        Container(
                          color: tileColor,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 15.0),
                            child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                          ),
                        ),
                        SettingsSwitch(
                          onChanged: (bool val) {
                            ss.settings.generateFakeMessageContent.value = val;
                            saveSettings();
                          },
                          initialVal: ss.settings.generateFakeMessageContent.value,
                          title: "Generate Fake Message Content",
                          backgroundColor: tileColor,
                          subtitle: "Replaces message text with lorem-ipsum text",
                        ),
                      ],
                    ),
                  ],
                ),
              )),
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
