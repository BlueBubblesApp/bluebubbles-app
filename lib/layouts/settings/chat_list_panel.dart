import 'dart:ui';

import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatListPanel extends StatelessWidget {

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
          preferredSize: Size(context.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(headerColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: headerColor.withOpacity(0.5),
                title: Text(
                  "Chat List",
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
            SliverList(
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
                        child: Text("Indicators".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )
                  ),
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.showConnectionIndicator.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.showConnectionIndicator.value,
                    title: "Show Connection Indicator",
                    subtitle: "Enables a connection status indicator at the top left",
                    backgroundColor: tileColor,
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.showSyncIndicator.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.showSyncIndicator.value,
                    title: "Show Sync Indicator in Chat List",
                    subtitle: "Enables a small indicator at the top left to show when the app is syncing messages",
                    backgroundColor: tileColor,
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.colorblindMode.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.colorblindMode.value,
                    title: "Colorblind Mode",
                    subtitle: "Replaces the colored connection indicator with icons to aid accessibility",
                    backgroundColor: tileColor,
                  )),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Filtering"
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.filteredChatList.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.filteredChatList.value,
                    title: "Filtered Chat List",
                    subtitle: "Filters the chat list based on parameters set in iMessage (usually this removes old, inactive chats)",
                    backgroundColor: tileColor,
                  )),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Appearance"
                  ),
                  Obx(() {
                    if (SettingsManager().settings.skin.value != Skins.Samsung)
                      return SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.hideDividers.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.hideDividers.value,
                        title: "Hide Dividers",
                        backgroundColor: tileColor,
                        subtitle: "Hides dividers between tiles",
                      );
                    else return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value != Skins.Samsung)
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      );
                    else return SizedBox.shrink();
                  }),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.denseChatTiles.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.denseChatTiles.value,
                    title: "Dense Conversation Tiles",
                    backgroundColor: tileColor,
                    subtitle: "Compresses chat tile size on the conversation list page",
                  )),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS)
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      );
                    else return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS)
                      return SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.reducedForehead.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.reducedForehead.value,
                        title: "Reduced Forehead",
                        backgroundColor: tileColor,
                        subtitle: "Reduces the appbar size on conversation pages",
                      );
                    else return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.Samsung ||
                        SettingsManager().settings.skin.value == Skins.Material)
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      );
                    else return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.Samsung ||
                        SettingsManager().settings.skin.value == Skins.Material)
                      return SettingsSwitch(
                        onChanged: (bool val) {
                          SettingsManager().settings.swipableConversationTiles.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.swipableConversationTiles.value,
                        title: "Swipe Actions for Conversation Tiles",
                        subtitle: "Enables swipe actions, such as pinning and deleting, for conversation tiles when using Material theme",
                        backgroundColor: tileColor,
                      );
                    else return SizedBox.shrink();
                  }),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Misc"
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.moveChatCreatorToHeader.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.moveChatCreatorToHeader.value,
                    title: "Move Chat Creator Button to Header",
                    subtitle: "Replaces the floating button at the bottom to a fixed button at the top",
                    backgroundColor: tileColor,
                  )),
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
            ),
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

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }
}