import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivateAPIPanelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PrivateAPIPanelController>(() => PrivateAPIPanelController());
  }
}

class PrivateAPIPanelController extends GetxController {
  late Settings _settingsCopy;
  final RxnInt macOSVersionNumber = RxnInt();
  final RxnString macOSVersion = RxnString();

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
    SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
      macOSVersionNumber.value = int.tryParse(res['data']['os_version'].toString().split(".")[0]);
      macOSVersion.value = res['data']['os_version'];
      if ((macOSVersionNumber.value ?? 10) > 10) _settingsCopy.enablePrivateAPI.value = false;
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
    final iosSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if (Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance()
        || SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: headerColor, // navigation bar color
        systemNavigationBarIconBrightness:
        headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: SettingsManager().settings.skin.value != Skins.iOS ? tileColor : headerColor,
        appBar: PreferredSize(
          preferredSize: Size(CustomNavigator.width(context), 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(headerColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: headerColor.withOpacity(0.5),
                title: Text(
                  "Private API Features",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: CustomScrollView(
          physics: ThemeSwitcher.getScrollPhysics(),
          slivers: <Widget>[
            Obx(() => SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  Container(
                      height: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 40,
                      alignment: Alignment.bottomLeft,
                      decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                        color: headerColor,
                        border: Border(
                            bottom: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                        ),
                      ) : BoxDecoration(
                        color: tileColor,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 15),
                        child: Text("Private API".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )
                  ),
                  Container(
                      decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                        color: tileColor,
                        border: Border(
                            bottom: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                        ),
                      ) : BoxDecoration(
                        color: tileColor,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: "Private API features give you the ability to send tapbacks, send read receipts, and see typing indicators."),
                              TextSpan(text: "\n\n"),
                              TextSpan(text: "These features are only available to those running the nightly version of the server on Mac OS 10.15 and under."),
                              TextSpan(text: "\n\n"),
                              TextSpan(text: "Please note that servers running Mac OS 11+ "),
                              TextSpan(text: "are not supported.", style: TextStyle(fontStyle: FontStyle.italic)),
                              TextSpan(text: "\n\n"),
                              TextSpan(text: "You must be using the nightly version of the server for these features to function, regardless of whether you enable them here."),
                            ],
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                        ),
                      )
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "Set up Private API Features",
                    subtitle: "View instructions on how to set up these features",
                    onTap: () async {
                      await launch("https://github.com/BlueBubblesApp/BlueBubbles-Server/wiki/Using-Private-API-Features");
                    },
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.checkmark_shield,
                      materialIcon: Icons.privacy_tip,
                    ),
                  ),
                  ((controller.macOSVersionNumber.value ?? 10) < 11) ?
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ) : Container(),
                  (controller.macOSVersionNumber.value ?? 10) < 11 ? SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.enablePrivateAPI.value = val;
                      saveSettings();
                    },
                    initialVal: controller._settingsCopy.enablePrivateAPI.value,
                    title: "Enable Private API Features",
                    backgroundColor: tileColor,
                  ) : Container(
                      decoration: BoxDecoration(
                        color: tileColor,
                        border: Border(
                            top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                        child: RichText(
                          text: TextSpan(
                              children: [
                                TextSpan(text: "Private API features are not supported on your server's macOS Version."),
                                TextSpan(text: "\n\n"),
                                TextSpan(text: "Current: ${controller.macOSVersion.value ?? "Unknown"}"),
                                TextSpan(text: "\n\n"),
                                TextSpan(text: "Required: 10.15.7 and under"),
                              ],
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                        ),
                      )
                  ),
                  if (SettingsManager().settings.enablePrivateAPI.value && (controller.macOSVersionNumber.value ?? 10) < 11)
                    ...[
                      SettingsHeader(
                          headerColor: headerColor,
                          tileColor: tileColor,
                          iosSubtitle: iosSubtitle,
                          materialSubtitle: materialSubtitle,
                          text: "Private API Settings"
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                         controller._settingsCopy.privateSendTypingIndicators.value = val;
                          saveSettings();
                        },
                        initialVal:controller._settingsCopy.privateSendTypingIndicators.value,
                        title: "Send Typing Indicators",
                        subtitle: "Sends typing indicators to other iMessage users",
                        backgroundColor: tileColor,
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                         controller._settingsCopy.privateMarkChatAsRead.value = val;
                          saveSettings();
                        },
                        initialVal:controller._settingsCopy.privateMarkChatAsRead.value,
                        title: "Mark Chats as Read / Send Read Receipts",
                        subtitle: "Marks chats read in the iMessage app on your server and sends read receipts to other iMessage users",
                        backgroundColor: tileColor,
                      ),
                      if (!controller._settingsCopy.privateMarkChatAsRead.value)
                        SettingsSwitch(
                          onChanged: (bool val) {
                           controller._settingsCopy.privateManualMarkAsRead.value = val;
                            saveSettings();
                          },
                          initialVal:controller._settingsCopy.privateManualMarkAsRead.value,
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
                          inactiveTrackColor: tileColor == Theme.of(context).accentColor
                              ? Theme.of(context).backgroundColor.withOpacity(0.6)
                              : Theme.of(context).accentColor.withOpacity(0.6),
                          inactiveThumbColor: tileColor == Theme.of(context).accentColor
                              ? Theme.of(context).backgroundColor
                              : Theme.of(context).accentColor,
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
                      Obx(() => SettingsManager().settings.enableQuickTapback.value ? Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      ) : SizedBox.shrink()),
                      Obx(() {
                        if (SettingsManager().settings.enableQuickTapback.value &&
                            SettingsManager().settings.skin.value == Skins.iOS)
                          return Container(
                            decoration: BoxDecoration(
                              color: tileColor,
                            ),
                            padding: EdgeInsets.only(left: 15),
                            child: Text("Select Quick Tapback"),
                          );
                        else
                          return SizedBox.shrink();
                      }),
                      Obx(() {
                        if (SettingsManager().settings.enableQuickTapback.value)
                          return SettingsOptions<String>(
                            title: "Quick Tapback",
                            options: ReactionTypes.toList(),
                            cupertinoCustomWidgets: [
                              Reaction(reactionType: ReactionTypes.LOVE)
                                  .getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
                              Reaction(reactionType: ReactionTypes.LIKE)
                                  .getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
                              Reaction(reactionType: ReactionTypes.DISLIKE)
                                  .getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
                              Reaction(reactionType: ReactionTypes.LAUGH)
                                  .getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
                              Reaction(reactionType: ReactionTypes.EMPHASIZE)
                                  .getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
                              Reaction(reactionType: ReactionTypes.QUESTION)
                                  .getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
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
                        else
                          return SizedBox.shrink();
                      }),
                    ],
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  Container(
                    height: 30,
                    decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                      color: headerColor,
                      border: Border(
                          top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                      ),
                    ) : null,
                  ),
                ],
              ),
            )),
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[],
              ),
            )
          ],
        ),
      ),
    );
  }

  void saveSettings() async {
    await SettingsManager().saveSettings(controller._settingsCopy);
  }
}
