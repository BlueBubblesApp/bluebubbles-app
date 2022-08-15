import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

class PrivateAPIPanelController extends GetxController {
  late Settings _settingsCopy;
  final RxInt serverVersionCode = RxInt(0);

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
    api.serverInfo().then((response) {
      final String? serverVersion = response.data['data']['server_version'];
      Version version = Version.parse(serverVersion!);
      serverVersionCode.value = version.major * 100 + version.minor * 21 + version.patch;
    });
  }

  void saveSettings() async {
    await SettingsManager().saveSettings(_settingsCopy);
  }

  @override
  void dispose() {
    saveSettings();
    super.dispose();
  }
}

class PrivateAPIPanel extends StatelessWidget {
  final controller = Get.put(PrivateAPIPanelController());

  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
    context.theme.textTheme.labelLarge?.copyWith(color: ThemeManager().inDarkMode(context) ? context.theme.colorScheme.onBackground : context.theme.colorScheme.properOnSurface, fontWeight: FontWeight.w300);
    final materialSubtitle = context.theme
        .textTheme
        .labelLarge
        ?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold);
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;
    
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material && ThemeManager().inDarkMode(context)) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }

    return SettingsScaffold(
        title: "Private API Features",
        initialHeader: "Private API",
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          Obx(() => SliverList(
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
                          title: "Set up Private API Features",
                          subtitle: "View instructions on how to set up these features",
                          onTap: () async {
                            await launchUrl(Uri(scheme: "https", host: "docs.bluebubbles.app", path: "helper-bundle/installation"));
                          },
                          leading: SettingsLeadingIcon(
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
                        SettingsSwitch(
                          onChanged: (bool val) {
                            controller._settingsCopy.enablePrivateAPI.value = val;
                            saveSettings();
                          },
                          initialVal: controller._settingsCopy.enablePrivateAPI.value,
                          title: "Enable Private API Features",
                          backgroundColor: tileColor,
                        ),
                      ],
                    ),
                    if (SettingsManager().settings.enablePrivateAPI.value) ...[
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
                              controller._settingsCopy.privateSendTypingIndicators.value = val;
                              saveSettings();
                            },
                            initialVal: controller._settingsCopy.privateSendTypingIndicators.value,
                            title: "Send Typing Indicators",
                            subtitle: "Sends typing indicators to other iMessage users",
                            backgroundColor: tileColor,
                          ),
                          if (!controller._settingsCopy.privateManualMarkAsRead.value)
                            Container(
                              color: tileColor,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 15.0),
                                child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                              ),
                            ),
                          if (!controller._settingsCopy.privateManualMarkAsRead.value)
                            SettingsSwitch(
                              onChanged: (bool val) {
                                controller._settingsCopy.privateMarkChatAsRead.value = val;
                                if (val) {
                                  controller._settingsCopy.privateManualMarkAsRead.value = false;
                                }
                                saveSettings();
                              },
                              initialVal: controller._settingsCopy.privateMarkChatAsRead.value,
                              title: "Automatic Mark Read / Send Read Receipts",
                              subtitle:
                                  "Marks chats read in the iMessage app on your server and sends read receipts to other iMessage users",
                              backgroundColor: tileColor,
                              isThreeLine: true,
                            ),
                          if (!controller._settingsCopy.privateMarkChatAsRead.value)
                            Container(
                              color: tileColor,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 15.0),
                                child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                              ),
                            ),
                          if (!controller._settingsCopy.privateMarkChatAsRead.value)
                            SettingsSwitch(
                              onChanged: (bool val) {
                                controller._settingsCopy.privateManualMarkAsRead.value = val;
                                saveSettings();
                              },
                              initialVal: controller._settingsCopy.privateManualMarkAsRead.value,
                              title: "Manual Mark Read / Send Read Receipts",
                              subtitle: "Only mark a chat read when pressing the manual mark read button",
                              backgroundColor: tileColor,
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
                            title: "Double-${kIsWeb || kIsDesktop ? "Click" : "Tap"} Message for Quick Tapback",
                            initialVal: SettingsManager().settings.enableQuickTapback.value,
                            onChanged: (bool val) {
                              SettingsManager().settings.enableQuickTapback.value = val;
                              if (val && SettingsManager().settings.doubleTapForDetails.value) {
                                SettingsManager().settings.doubleTapForDetails.value = false;
                              }
                              saveSettings();
                            },
                            subtitle: "Send a tapback of your choosing when double ${kIsWeb || kIsDesktop ? "click" : "tapp"}ing a message",
                            backgroundColor: tileColor,
                            isThreeLine: true,
                          ),
                          Obx(() {
                            if (SettingsManager().settings.enableQuickTapback.value) {
                              return SettingsOptions<String>(
                                title: "Quick Tapback",
                                options: ReactionTypes.toList(),
                                cupertinoCustomWidgets: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.LOVE).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: SettingsManager().settings.quickTapbackType.value == ReactionTypes.LOVE)!,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.LIKE).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: SettingsManager().settings.quickTapbackType.value == ReactionTypes.LIKE)!,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.DISLIKE).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: SettingsManager().settings.quickTapbackType.value == ReactionTypes.DISLIKE)!,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.LAUGH).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: SettingsManager().settings.quickTapbackType.value == ReactionTypes.LAUGH)!,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.EMPHASIZE).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: SettingsManager().settings.quickTapbackType.value == ReactionTypes.EMPHASIZE)!,
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Reaction(reactionType: ReactionTypes.QUESTION).getSmallWidget(context,
                                        message: Message(isFromMe: true), isReactionPicker: true, isSelected: SettingsManager().settings.quickTapbackType.value == ReactionTypes.QUESTION)!,
                                  ),
                                ],
                                initial: SettingsManager().settings.quickTapbackType.value,
                                textProcessing: (val) => val,
                                onChanged: (val) {
                                  if (val == null) return;
                                  SettingsManager().settings.quickTapbackType.value = val;
                                  saveSettings();
                                },
                                backgroundColor: tileColor,
                                secondaryColor: headerColor,
                              );
                            } else {
                              return SizedBox.shrink();
                            }
                          }),
                          Obx(() => controller.serverVersionCode.value >= 63 ? Container(
                            color: tileColor,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 15.0),
                              child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                            ),
                          ) : SizedBox.shrink()),
                          Obx(() {
                            if (controller.serverVersionCode.value >= 63) {
                              return SettingsSwitch(
                                onChanged: (bool val) {
                                  controller._settingsCopy.privateSubjectLine.value = val;
                                  saveSettings();
                                },
                                initialVal: controller._settingsCopy.privateSubjectLine.value,
                                title: "Send Subject Lines",
                                backgroundColor: tileColor,
                              );
                            } else {
                              return SizedBox.shrink();
                            }
                          }),
                          FutureBuilder(
                              initialData: false,
                              future: SettingsManager().isMinBigSur,
                              builder: (context, snapshot) {
                                return Obx(() {
                                  if (controller.serverVersionCode.value >= 63 && snapshot.data as bool) {
                                    return Column(
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
                                            controller._settingsCopy.swipeToReply.value = val;
                                            saveSettings();
                                          },
                                          initialVal: controller._settingsCopy.swipeToReply.value,
                                          title: "Swipe Messages to Reply",
                                          backgroundColor: tileColor,
                                        ),
                                      ],
                                    );
                                  } else {
                                    return SizedBox.shrink();
                                  }
                                });
                              }),
                          Obx(() => controller.serverVersionCode.value >= 84 ? Container(
                            color: tileColor,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 15.0),
                              child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                            ),
                          ) : SizedBox.shrink()),
                          Obx(() {
                            if (controller.serverVersionCode.value >= 84) {
                              return SettingsSwitch(
                                onChanged: (bool val) {
                                  controller._settingsCopy.privateAPISend.value = val;
                                  saveSettings();
                                },
                                initialVal: controller._settingsCopy.privateAPISend.value,
                                title: "Private API Send",
                                subtitle: "Send regular iMessages using the Private API for much faster speed",
                                backgroundColor: tileColor,
                                isThreeLine: true,
                              );
                            } else {
                              return SizedBox.shrink();
                            }
                          }),
                        ],
                      )
                    ],
                  ],
                ),
              )),
        ]);
  }

  void saveSettings() async {
    await SettingsManager().saveSettings(controller._settingsCopy);
  }
}
