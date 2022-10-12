import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/repository/models/models.dart';
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
  PrivateAPIPanel() : super(parentController: Get.put(PrivateAPIPanelController()));

  @override
  State<StatefulWidget> createState() => _PrivateAPIPanelState();
}

class _PrivateAPIPanelState extends CustomState<PrivateAPIPanel, void, PrivateAPIPanelController> with ThemeHelpers {

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
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: "Private API features give you the ability to:\n"),
                            TextSpan(text: " - Send tapbacks\n"),
                            TextSpan(text: " - Send read receipts\n"),
                            TextSpan(text: " - Send & receive typing indicators\n"),
                            TextSpan(text: " - Mark chats read on the Mac server\n"),
                            TextSpan(text: " - Send messages with subject lines\n"),
                            TextSpan(text: " - Send message effects\n"),
                            TextSpan(text: " - Change group chat names\n"),
                            TextSpan(text: " - Add & remove people from group chats\n"),
                            TextSpan(text: " - Send replies (requires Big Sur and up)"),
                            TextSpan(text: "\n\n"),
                            TextSpan(
                                text:
                                    "You must have the Private API bundle installed on the server for these features to function, regardless of whether you enable the setting here."),
                          ],
                          style: context.theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Set up Private API Features",
                      subtitle: "View instructions on how to set up these features",
                      onTap: () async {
                        await launchUrl(Uri(scheme: "https", host: "docs.bluebubbles.app", path: "helper-bundle/installation"));
                      },
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.checkmark_shield,
                        materialIcon: Icons.privacy_tip,
                      ),
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        settings.settings.enablePrivateAPI.value = val;
                        saveSettings();
                      },
                      initialVal: settings.settings.enablePrivateAPI.value,
                      title: "Enable Private API Features",
                      backgroundColor: tileColor,
                    )),
                  ],
                ),
                Obx(() => AnimatedSizeAndFade.showHide(
                  show: settings.settings.enablePrivateAPI.value,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SettingsHeader(
                            headerColor: headerColor,
                            tileColor: tileColor,
                            iosSubtitle: iosSubtitle,
                            materialSubtitle: materialSubtitle,
                            text: "Private API Settings"),
                        SettingsSection(
                          backgroundColor: tileColor,
                          children: [
                            SettingsSwitch(
                              onChanged: (bool val) {
                                settings.settings.privateSendTypingIndicators.value = val;
                                saveSettings();
                              },
                              initialVal: settings.settings.privateSendTypingIndicators.value,
                              title: "Send Typing Indicators",
                              subtitle: "Sends typing indicators to other iMessage users",
                              backgroundColor: tileColor,
                            ),
                            AnimatedSizeAndFade(
                              child: !settings.settings.privateManualMarkAsRead.value ? Column(
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
                                      settings.settings.privateMarkChatAsRead.value = val;
                                      if (val) {
                                        settings.settings.privateManualMarkAsRead.value = false;
                                      }
                                      saveSettings();
                                    },
                                    initialVal: settings.settings.privateMarkChatAsRead.value,
                                    title: "Automatic Mark Read / Send Read Receipts",
                                    subtitle:
                                    "Marks chats read in the iMessage app on your server and sends read receipts to other iMessage users",
                                    backgroundColor: tileColor,
                                    isThreeLine: true,
                                  ),
                                ],
                              ) : const SizedBox.shrink(),
                            ),
                            AnimatedSizeAndFade.showHide(
                              show: !settings.settings.privateMarkChatAsRead.value,
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
                                      settings.settings.privateManualMarkAsRead.value = val;
                                      saveSettings();
                                    },
                                    initialVal: settings.settings.privateManualMarkAsRead.value,
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
                              initialVal: settings.settings.enableQuickTapback.value,
                              onChanged: (bool val) {
                                settings.settings.enableQuickTapback.value = val;
                                if (val && settings.settings.doubleTapForDetails.value) {
                                  settings.settings.doubleTapForDetails.value = false;
                                }
                                saveSettings();
                              },
                              subtitle: "Send a tapback of your choosing when double ${kIsWeb || kIsDesktop ? "click" : "tapp"}ing a message",
                              backgroundColor: tileColor,
                              isThreeLine: true,
                            ),
                            AnimatedSizeAndFade.showHide(
                              show: settings.settings.enableQuickTapback.value,
                              child: SettingsOptions<String>(
                                title: "Quick Tapback",
                                options: ReactionTypes.toList(),
                                cupertinoCustomWidgets: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.LOVE).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: settings.settings.quickTapbackType.value == ReactionTypes.LOVE)!,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.LIKE).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: settings.settings.quickTapbackType.value == ReactionTypes.LIKE)!,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.DISLIKE).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: settings.settings.quickTapbackType.value == ReactionTypes.DISLIKE)!,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.LAUGH).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: settings.settings.quickTapbackType.value == ReactionTypes.LAUGH)!,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.EMPHASIZE).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: settings.settings.quickTapbackType.value == ReactionTypes.EMPHASIZE)!,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.QUESTION).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: settings.settings.quickTapbackType.value == ReactionTypes.QUESTION)!,
                                  ),
                                ],
                                initial: settings.settings.quickTapbackType.value,
                                textProcessing: (val) => val,
                                onChanged: (val) {
                                  if (val == null) return;
                                  settings.settings.quickTapbackType.value = val;
                                  saveSettings();
                                },
                                backgroundColor: tileColor,
                                secondaryColor: headerColor,
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
                                      settings.settings.privateSubjectLine.value = val;
                                      saveSettings();
                                    },
                                    initialVal: settings.settings.privateSubjectLine.value,
                                    title: "Send Subject Lines",
                                    backgroundColor: tileColor,
                                  ),
                                  Container(
                                    color: tileColor,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 15.0),
                                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                    ),
                                  ),
                                  FutureBuilder(
                                      initialData: false,
                                      future: settings.isMinBigSur,
                                      builder: (context, snapshot) {
                                        if (snapshot.data as bool) {
                                          return Column(
                                            children: [
                                              Container(
                                                color: tileColor,
                                                child: Padding(
                                                  padding: const EdgeInsets.only(left: 15.0),
                                                  child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                                ),
                                              ),
                                              Obx(() => SettingsSwitch(
                                                onChanged: (bool val) {
                                                  settings.settings.swipeToReply.value = val;
                                                  saveSettings();
                                                },
                                                initialVal: settings.settings.swipeToReply.value,
                                                title: "Swipe Messages to Reply",
                                                backgroundColor: tileColor,
                                              )),
                                            ],
                                          );
                                        } else {
                                          return const SizedBox.shrink();
                                        }
                                      }),
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
                                      settings.settings.privateAPISend.value = val;
                                      saveSettings();
                                    },
                                    initialVal: settings.settings.privateAPISend.value,
                                    title: "Private API Send",
                                    subtitle: "Send regular iMessages using the Private API for much faster speed",
                                    backgroundColor: tileColor,
                                    isThreeLine: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      ]
                  ),
                )),
              ],
            ),
          ),
        ]);
  }

  void saveSettings() async {
    await settings.saveSettings();
  }
}
