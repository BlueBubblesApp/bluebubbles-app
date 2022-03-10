import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

class PrivateAPIPanelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PrivateAPIPanelController>(() => PrivateAPIPanelController());
  }
}

class PrivateAPIPanelController extends GetxController {
  late Settings _settingsCopy;
  final RxnInt serverVersionCode = RxnInt();

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
    SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
      final String? serverVersion = res['data']['server_version'];
      Version version = Version.parse(serverVersion);
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

class PrivateAPIPanel extends GetView<PrivateAPIPanelController> {
  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
        Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context)
        .textTheme
        .subtitle1
        ?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if ((Theme.of(context).colorScheme.secondary.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
            SettingsManager().settings.skin.value == Skins.Material) &&
        (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
      headerColor = Theme.of(context).colorScheme.secondary;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).colorScheme.secondary;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
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
                        Container(
                            decoration: SettingsManager().settings.skin.value == Skins.iOS
                                ? BoxDecoration(
                                    color: tileColor,
                                    border: Border(
                                        bottom: BorderSide(
                                            color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                                  )
                                : BoxDecoration(
                                    color: tileColor,
                                  ),
                            child: Padding(
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
                                  style: Theme.of(context).textTheme.bodyText1,
                                ),
                              ),
                            )),
                        SettingsTile(
                          backgroundColor: tileColor,
                          title: "Set up Private API Features",
                          subtitle: "View instructions on how to set up these features",
                          onTap: () async {
                            await launch(
                                "https://docs.bluebubbles.app/helper-bundle/installation");
                          },
                          leading: SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.checkmark_shield,
                            materialIcon: Icons.privacy_tip,
                          ),
                        ),
                        Container(
                          color: tileColor,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 65.0),
                            child: SettingsDivider(color: headerColor),
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
                          SettingsSwitch(
                            onChanged: (bool val) {
                              controller._settingsCopy.privateMarkChatAsRead.value = val;
                              if (val) {
                                controller._settingsCopy.privateManualMarkAsRead.value = false;
                              }
                              saveSettings();
                            },
                            initialVal: controller._settingsCopy.privateMarkChatAsRead.value,
                            title: "Mark Chats as Read / Send Read Receipts",
                            subtitle:
                                "Marks chats read in the iMessage app on your server and sends read receipts to other iMessage users",
                            backgroundColor: tileColor,
                          ),
                          if (!controller._settingsCopy.privateMarkChatAsRead.value)
                            SettingsSwitch(
                              onChanged: (bool val) {
                                controller._settingsCopy.privateManualMarkAsRead.value = val;
                                saveSettings();
                              },
                              initialVal: controller._settingsCopy.privateManualMarkAsRead.value,
                              title: "Show Manually Mark Chat as Read Button",
                              backgroundColor: tileColor,
                            ),
                          Container(
                            color: tileColor,
                            child: SwitchListTile(
                              title: Text(
                                "Double-${kIsWeb || kIsDesktop ? "Click" : "Tap"} Message for Quick Tapback",
                                style: Theme.of(context).textTheme.bodyText1,
                              ),
                              value: SettingsManager().settings.enableQuickTapback.value,
                              activeColor: Theme.of(context).primaryColor,
                              activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
                              inactiveTrackColor: tileColor == Theme.of(context).colorScheme.secondary
                                  ? Theme.of(context).backgroundColor.withOpacity(0.6)
                                  : Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                              inactiveThumbColor: tileColor == Theme.of(context).colorScheme.secondary
                                  ? Theme.of(context).backgroundColor
                                  : Theme.of(context).colorScheme.secondary,
                              onChanged: (bool val) {
                                SettingsManager().settings.enableQuickTapback.value = val;
                                if (val && SettingsManager().settings.doubleTapForDetails.value) {
                                  SettingsManager().settings.doubleTapForDetails.value = false;
                                }
                                saveSettings();
                              },
                              subtitle: Text(
                                  "Send a tapback of your choosing when double ${kIsWeb || kIsDesktop ? "click" : "tapp"}ing a message",
                                  style: Theme.of(context).textTheme.subtitle1),
                              tileColor: tileColor,
                            ),
                          ),
                          Obx(() => SettingsManager().settings.enableQuickTapback.value
                              ? Container(
                                  color: tileColor,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 65.0),
                                    child: SettingsDivider(color: headerColor),
                                  ),
                                )
                              : SizedBox.shrink()),
                          Obx(() {
                            if (SettingsManager().settings.enableQuickTapback.value &&
                                SettingsManager().settings.skin.value == Skins.iOS) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: tileColor,
                                ),
                                padding: EdgeInsets.only(left: 15),
                                child: Text("Select Quick Tapback"),
                              );
                            } else {
                              return SizedBox.shrink();
                            }
                          }),
                          Obx(() {
                            if (SettingsManager().settings.enableQuickTapback.value) {
                              return SettingsOptions<String>(
                                title: "Quick Tapback",
                                options: ReactionTypes.toList(),
                                cupertinoCustomWidgets: [
                                  Reaction(reactionType: ReactionTypes.LOVE).getSmallWidget(context,
                                      message: Message(isFromMe: true), isReactionPicker: true)!,
                                  Reaction(reactionType: ReactionTypes.LIKE).getSmallWidget(context,
                                      message: Message(isFromMe: true), isReactionPicker: true)!,
                                  Reaction(reactionType: ReactionTypes.DISLIKE).getSmallWidget(context,
                                      message: Message(isFromMe: true), isReactionPicker: true)!,
                                  Reaction(reactionType: ReactionTypes.LAUGH).getSmallWidget(context,
                                      message: Message(isFromMe: true), isReactionPicker: true)!,
                                  Reaction(reactionType: ReactionTypes.EMPHASIZE).getSmallWidget(context,
                                      message: Message(isFromMe: true), isReactionPicker: true)!,
                                  Reaction(reactionType: ReactionTypes.QUESTION).getSmallWidget(context,
                                      message: Message(isFromMe: true), isReactionPicker: true)!,
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
                          Obx(() {
                            if ((controller.serverVersionCode.value ?? 0) >= 63) {
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
                              future: SettingsManager().getMacOSVersion().then((val) => (val ?? 0) >= 11),
                              builder: (context, snapshot) {
                                return Obx(() {
                                  if ((controller.serverVersionCode.value ?? 0) >= 63 && snapshot.data as bool) {
                                    return SettingsSwitch(
                                      onChanged: (bool val) {
                                        controller._settingsCopy.swipeToReply.value = val;
                                        saveSettings();
                                      },
                                      initialVal: controller._settingsCopy.swipeToReply.value,
                                      title: "Swipe Messages to Reply",
                                      backgroundColor: tileColor,
                                    );
                                  } else {
                                    return SizedBox.shrink();
                                  }
                                });
                              }),
                          Obx(() {
                            if ((controller.serverVersionCode.value ?? 0) >= 84) {
                              return SettingsSwitch(
                                onChanged: (bool val) {
                                  controller._settingsCopy.privateAPISend.value = val;
                                  saveSettings();
                                },
                                initialVal: controller._settingsCopy.privateAPISend.value,
                                title: "Private API Send",
                                subtitle: "Send regular iMessages using the Private API for much faster speed",
                                backgroundColor: tileColor,
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
