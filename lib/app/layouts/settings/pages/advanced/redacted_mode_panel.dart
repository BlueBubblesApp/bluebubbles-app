import 'dart:math';

import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/image_viewer.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/message_sender.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RedactedModePanel extends StatefulWidget {
  const RedactedModePanel({super.key});

  @override
  State<StatefulWidget> createState() => _RedactedModePanelState();
}

class _RedactedModePanelState extends State<RedactedModePanel> with ThemeHelpers {
  late final Message message = (() {
    final m = Message(
      guid: "redacted-mode-demo",
      dateDelivered: DateTime.now().toLocal(),
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
    );
    m.dbAttachments.add(
      Attachment(
        guid: "redacted-mode-demo-attachment",
        originalROWID: Random.secure().nextInt(10000),
        transferName: "assets/icon/icon.png",
        mimeType: "image/png",
        width: 100,
        height: 100,
      ),
    );
    return m;
  })();
  late final MessagePart _previewPart = MessagePart(part: 0, text: message.text, subject: message.subject);
  final RxInt placeholder = 0.obs;

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
                          "Redacted Mode hides sensitive information, such as contact names, message content, and more. This is useful when taking screenshots to send to developers."),
                    ),
                  ],
                ),
                Theme(
                  data: context.theme.copyWith(
                    // in case some components still use legacy theming
                    primaryColor: context.theme.colorScheme.bubble(context, true),
                    colorScheme: context.theme.colorScheme.copyWith(
                      primary: context.theme.colorScheme.bubble(context, true),
                      onPrimary: context.theme.colorScheme.onBubble(context, true),
                      surface: ThemeSvc.isMaterialYouActive(context)
                          ? null
                          : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
                      onSurface: ThemeSvc.isMaterialYouActive(context)
                          ? null
                          : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
                    ),
                  ),
                  child: Builder(builder: (context) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
                      child: AbsorbPointer(
                        child: Obx(() {
                          // used to update preview real-time
                          // ignore: unused_local_variable
                          final _placeholder = placeholder.value;
                          _previewPart.shouldRedact =
                              SettingsSvc.settings.redactedMode.value && SettingsSvc.settings.hideMessageContent.value;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ContactAvatarWidget(
                                handle: message.handle,
                                size: iOS ? 30 : 35,
                                fontSize: context.theme.textTheme.bodyLarge!.fontSize!,
                                borderThickness: 0.1,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 5.0),
                                    child: MessageSender(olderMessage: null),
                                  ),
                                  ClipPath(
                                    clipper: TailClipper(
                                      isFromMe: false,
                                      showTail: false,
                                      connectLower: false,
                                      connectUpper: false,
                                    ),
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: NavigationSvc.width(context) * 0.3,
                                        maxHeight: context.height * 0.3,
                                        minHeight: 40,
                                        minWidth: 40,
                                      ),
                                      padding: const EdgeInsets.only(left: 10),
                                      color: context.theme.colorScheme.surfaceContainerHighest,
                                      child: Center(
                                        widthFactor: 1,
                                        heightFactor: 1,
                                        child: AnimatedOpacity(
                                          duration: const Duration(milliseconds: 150),
                                          opacity: SettingsSvc.settings.redactedMode.value &&
                                                  SettingsSvc.settings.hideAttachments.value
                                              ? 0
                                              : 1,
                                          child: ImageViewer(
                                            file: AttachmentsSvc.getContent(message.dbAttachments.first),
                                            attachment: message.dbAttachments.first,
                                            isFromMe: false,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  ClipPath(
                                    clipper: TailClipper(
                                      isFromMe: false,
                                      showTail: true,
                                      connectLower: false,
                                      connectUpper: false,
                                    ),
                                    child: Container(
                                      constraints: BoxConstraints(
                                        maxWidth: NavigationSvc.width(context) * MessageState.maxBubbleSizeFactor - 40,
                                        minHeight: 40,
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15)
                                          .add(const EdgeInsets.only(left: 10)),
                                      color: context.theme.colorScheme.surfaceContainerHighest,
                                      child: Center(
                                        widthFactor: 1,
                                        child: RichText(
                                          text: TextSpan(
                                            children: buildMessageSpans(
                                              context,
                                              _previewPart,
                                              message,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }),
                      ),
                    );
                  }),
                ),
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Obx(() => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsSvc.settings.redactedMode.value = val;
                            await saveSettings('redactedMode');
                          },
                          initialVal: SettingsSvc.settings.redactedMode.value,
                          title: "Enable Redacted Mode",
                          backgroundColor: tileColor,
                        )),
                  ],
                ),
                Obx(() => AnimatedSizeAndFade.showHide(
                      show: SettingsSvc.settings.redactedMode.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SettingsHeader(
                              iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Customization"),
                          SettingsSection(
                            backgroundColor: tileColor,
                            children: [
                              SettingsSwitch(
                                onChanged: (bool val) async {
                                  SettingsSvc.settings.hideMessageContent.value = val;
                                  await saveSettings('hideMessageContent');
                                },
                                initialVal: SettingsSvc.settings.hideMessageContent.value,
                                title: "Hide Message Content",
                                backgroundColor: tileColor,
                                subtitle: "Replace message text with generated lorem ipsum",
                              ),
                              const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                              SettingsSwitch(
                                onChanged: (bool val) async {
                                  SettingsSvc.settings.hideAttachments.value = val;
                                  await saveSettings('hideAttachments');
                                },
                                initialVal: SettingsSvc.settings.hideAttachments.value,
                                title: "Hide Attachments",
                                backgroundColor: tileColor,
                                subtitle: "Replace attachments with placeholder boxes",
                              ),
                              const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                              SettingsSwitch(
                                onChanged: (bool val) async {
                                  SettingsSvc.settings.hideContactInfo.value = val;
                                  await saveSettings('hideContactInfo');
                                },
                                initialVal: SettingsSvc.settings.hideContactInfo.value,
                                title: "Hide Contact Info",
                                backgroundColor: tileColor,
                                subtitle: "Replace contact info with fake names and hide contact photos",
                                isThreeLine: true,
                              ),
                              const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                              SettingsSwitch(
                                onChanged: (bool val) async {
                                  SettingsSvc.settings.generateFakeAvatars.value = val;
                                  await saveSettings('generateFakeAvatars');
                                },
                                initialVal: SettingsSvc.settings.generateFakeAvatars.value,
                                title: "Generate Fake Avatars",
                                backgroundColor: tileColor,
                                subtitle: "Use the Dice Bear service to generate fake avatars for contacts",
                                isThreeLine: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ]);
  }

  Future<void> saveSettings(String key) async {
    placeholder.value += 1;
    await SettingsSvc.settings.saveOneAsync(key);
  }
}
