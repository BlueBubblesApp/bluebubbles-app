import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

class PrivateAPIPanelController extends StatefulController {
  final RxInt serverVersionCode = RxInt(0);

  @override
  void onReady() {
    super.onReady();
    updateObx(() {
      http.serverInfo().then((response) {
        final String serverVersion = response.data['data']['server_version'] ?? "0.0.1";
        Version version = Version.parse(serverVersion);
        serverVersionCode.value = version.major * 100 + version.minor * 21 + version.patch;
      });
    });
  }
}

class PrivateAPIPanel extends CustomStateful<PrivateAPIPanelController> {
  PrivateAPIPanel({this.enablePrivateAPIonInit = false}) : super(parentController: Get.put(PrivateAPIPanelController()));

  final bool enablePrivateAPIonInit;

  @override
  State<StatefulWidget> createState() => _PrivateAPIPanelState();
}

class _PrivateAPIPanelState extends CustomState<PrivateAPIPanel, void, PrivateAPIPanelController> {
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await ss.getServerDetails(refresh: true);
      if (widget.enablePrivateAPIonInit && ss.settings.serverPrivateAPI.value == true) {
        ss.settings.enablePrivateAPI.value = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
        title: "Private API Features",
        initialHeader: "Private API",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                Obx(
                  () => SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      if (!ss.settings.enablePrivateAPI.value || ss.settings.serverPrivateAPI.value != true)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(text: "Private API features give you the ability to:\n"),
                                const TextSpan(text: " - Send tapbacks, effects, and mentions\n"),
                                const TextSpan(text: " - Send messages with subject lines\n"),
                                if (ss.isMinBigSurSync) const TextSpan(text: " - Send replies\n"),
                                if (ss.isMinVenturaSync) const TextSpan(text: " - Edit & Unsend messages\n"),
                                if (ss.isMinBigSurSync) const TextSpan(text: " - Receive Digital Touch messages\n"),
                                const TextSpan(text: "\n"),
                                const TextSpan(text: " - Mark chats read on the Mac server\n"),
                                if (ss.isMinVenturaSync) const TextSpan(text: " - Mark chats as unread on the Mac server\n"),
                                const TextSpan(text: "\n"),
                                const TextSpan(text: " - Rename group chats\n"),
                                const TextSpan(text: " - Add & remove people from group chats\n"),
                                if (ss.isMinBigSurSync) const TextSpan(text: " - Change the group chat photo\n"),
                                const TextSpan(text: "\n"),
                                const TextSpan(text: " - Know if a recipient is registered with iMessage\n"),
                                if (ss.isMinMontereySync) const TextSpan(text: " - View Focus statuses\n"),
                                if (ss.isMinBigSurSync) const TextSpan(text: " - Use Find My Friends\n"),
                                if (ss.isMinBigSurSync) const TextSpan(text: " - Be notified of incoming FaceTime calls\n"),
                                if (ss.isMinVenturaSync) const TextSpan(text: " - Answer FaceTime calls (experimental)\n"),
                                const TextSpan(text: "\n"),
                                const TextSpan(
                                    text:
                                        "You must have the Private API bundle installed on the server for these features to function, regardless of whether you enable the setting here."),
                              ],
                              style: context.theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      if (ss.settings.serverPrivateAPI.value != true)
                        SettingsTile(
                          backgroundColor: tileColor,
                          title: "Set up Private API Features",
                          subtitle: "View instructions on how to set up these features",
                          onTap: () async {
                            await launchUrl(Uri(scheme: "https", host: "docs.bluebubbles.app", path: "helper-bundle/installation"),
                                mode: LaunchMode.externalApplication);
                          },
                          leading: const SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.checkmark_shield,
                            materialIcon: Icons.privacy_tip,
                          ),
                        ),
                      if (ss.settings.serverPrivateAPI.value != true)
                        Container(
                          color: tileColor,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 15.0),
                            child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                          ),
                        ),
                      Obx(
                        () => SettingsSwitch(
                          onChanged: (bool val) async {
                            ss.settings.enablePrivateAPI.value = val;
                            saveSettings();
                            await ss.prefs.remove('private-api-enable-tip');
                          },
                          initialVal: ss.settings.enablePrivateAPI.value,
                          title: "Enable Private API Features",
                          subtitle: ss.settings.serverPrivateAPI.value != null
                              ? "Private API features are ${ss.settings.serverPrivateAPI.value! ? "set up" : "not set up"} on the server${!ss.settings.serverPrivateAPI.value! ? "!" : ""}"
                              : null,
                          backgroundColor: tileColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Obx(
                  () => AnimatedSizeAndFade.showHide(
                    show: ss.settings.enablePrivateAPI.value,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Private API Settings"),
                      SettingsSection(
                        backgroundColor: tileColor,
                        children: [
                          SettingsSwitch(
                            onChanged: (bool val) {
                              ss.settings.privateSendTypingIndicators.value = val;
                              saveSettings();
                            },
                            initialVal: ss.settings.privateSendTypingIndicators.value,
                            title: "Send Typing Indicators",
                            subtitle: "Sends typing indicators to other iMessage users",
                            backgroundColor: tileColor,
                          ),
                          AnimatedSizeAndFade(
                            child: !ss.settings.privateManualMarkAsRead.value
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        color: tileColor,
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 15.0),
                                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                        ),
                                      ),
                                      SettingsSwitch(
                                        onChanged: (bool val) {
                                          ss.settings.privateMarkChatAsRead.value = val;
                                          if (val) {
                                            ss.settings.privateManualMarkAsRead.value = false;
                                          }
                                          saveSettings();
                                        },
                                        initialVal: ss.settings.privateMarkChatAsRead.value,
                                        title: "Automatic Mark Read / Send Read Receipts",
                                        subtitle:
                                            "Marks chats read in the iMessage app on your server and sends read receipts to other iMessage users",
                                        backgroundColor: tileColor,
                                        isThreeLine: true,
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: !ss.settings.privateMarkChatAsRead.value,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  color: tileColor,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 15.0),
                                    child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                  ),
                                ),
                                SettingsSwitch(
                                  onChanged: (bool val) {
                                    ss.settings.privateManualMarkAsRead.value = val;
                                    saveSettings();
                                  },
                                  initialVal: ss.settings.privateManualMarkAsRead.value,
                                  title: "Manual Mark Read / Send Read Receipts",
                                  subtitle: "Only mark a chat read when pressing the manual mark read button",
                                  backgroundColor: tileColor,
                                  isThreeLine: true,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            color: tileColor,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 15.0),
                              child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                            ),
                          ),
                          SettingsSwitch(
                            title: "Double-${kIsWeb || kIsDesktop ? "Click" : "Tap"} Message for Quick Tapback",
                            initialVal: ss.settings.enableQuickTapback.value,
                            onChanged: (bool val) {
                              ss.settings.enableQuickTapback.value = val;
                              if (val && ss.settings.doubleTapForDetails.value) {
                                ss.settings.doubleTapForDetails.value = false;
                              }
                              saveSettings();
                            },
                            subtitle: "Send a tapback of your choosing when double ${kIsWeb || kIsDesktop ? "click" : "tapp"}ing a message",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: ss.settings.enableQuickTapback.value,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 5.0),
                              child: SettingsOptions<String>(
                                title: "Quick Tapback",
                                options: ReactionTypes.toList(),
                                cupertinoCustomWidgets: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 7.5),
                                    child: ReactionWidget(
                                      reaction: Message(
                                          guid: "",
                                          associatedMessageType: ReactionTypes.LOVE,
                                          isFromMe: ss.settings.quickTapbackType.value != ReactionTypes.LOVE),
                                      message: null,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 7.5),
                                    child: ReactionWidget(
                                      reaction: Message(
                                          guid: "",
                                          associatedMessageType: ReactionTypes.LIKE,
                                          isFromMe: ss.settings.quickTapbackType.value != ReactionTypes.LIKE),
                                      message: null,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 7.5),
                                    child: ReactionWidget(
                                      reaction: Message(
                                          guid: "",
                                          associatedMessageType: ReactionTypes.DISLIKE,
                                          isFromMe: ss.settings.quickTapbackType.value != ReactionTypes.DISLIKE),
                                      message: null,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 7.5),
                                    child: ReactionWidget(
                                      reaction: Message(
                                          guid: "",
                                          associatedMessageType: ReactionTypes.LAUGH,
                                          isFromMe: ss.settings.quickTapbackType.value != ReactionTypes.LAUGH),
                                      message: null,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 7.5),
                                    child: ReactionWidget(
                                      reaction: Message(
                                          guid: "",
                                          associatedMessageType: ReactionTypes.EMPHASIZE,
                                          isFromMe: ss.settings.quickTapbackType.value != ReactionTypes.EMPHASIZE),
                                      message: null,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 7.5),
                                    child: ReactionWidget(
                                      reaction: Message(
                                          guid: "",
                                          associatedMessageType: ReactionTypes.QUESTION,
                                          isFromMe: ss.settings.quickTapbackType.value != ReactionTypes.QUESTION),
                                      message: null,
                                    ),
                                  ),
                                ],
                                initial: ss.settings.quickTapbackType.value,
                                textProcessing: (val) => val,
                                onChanged: (val) {
                                  if (val == null) return;
                                  ss.settings.quickTapbackType.value = val;
                                  saveSettings();
                                },
                                secondaryColor: headerColor,
                              ),
                            ),
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: ss.isMinVenturaSync && ss.serverDetailsSync().item4 >= 148,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  color: tileColor,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 15.0),
                                    child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                  ),
                                ),
                                SettingsSwitch(
                                  title: "Up Arrow for Quick Edit",
                                  initialVal: ss.settings.editLastSentMessageOnUpArrow.value,
                                  onChanged: (bool val) {
                                    ss.settings.editLastSentMessageOnUpArrow.value = val;
                                    saveSettings();
                                  },
                                  subtitle: "Press the Up Arrow to begin editing the last message you sent",
                                  backgroundColor: tileColor,
                                ),
                              ],
                            ),
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: controller.serverVersionCode.value >= 63,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  color: tileColor,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 15.0),
                                    child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                  ),
                                ),
                                SettingsSwitch(
                                  onChanged: (bool val) {
                                    ss.settings.privateSubjectLine.value = val;
                                    saveSettings();
                                  },
                                  initialVal: ss.settings.privateSubjectLine.value,
                                  title: "Send Subject Lines",
                                  backgroundColor: tileColor,
                                ),
                              ],
                            ),
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: controller.serverVersionCode.value >= 84,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  color: tileColor,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 15.0),
                                    child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                  ),
                                ),
                                SettingsSwitch(
                                  onChanged: (bool val) {
                                    ss.settings.privateAPISend.value = val;
                                    saveSettings();
                                  },
                                  initialVal: ss.settings.privateAPISend.value,
                                  title: "Private API Send",
                                  subtitle: "Send regular iMessages using the Private API for much faster speed",
                                  backgroundColor: tileColor,
                                  isThreeLine: true,
                                ),
                              ],
                            ),
                          ),
                          AnimatedSizeAndFade.showHide(
                            show: controller.serverVersionCode.value >= 208,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  color: tileColor,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 15.0),
                                    child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                  ),
                                ),
                                SettingsSwitch(
                                  onChanged: (bool val) {
                                    ss.settings.privateAPIAttachmentSend.value = val;
                                    saveSettings();
                                  },
                                  initialVal: ss.settings.privateAPIAttachmentSend.value,
                                  title: "Private API Attachment Send",
                                  subtitle: "Send attachments using the Private API",
                                  backgroundColor: tileColor,
                                  isThreeLine: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ]);
  }

  void saveSettings() async {
    await ss.saveSettings();
  }
}
