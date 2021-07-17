import 'dart:ui';

import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConversationPanel extends StatefulWidget {
  ConversationPanel({Key? key}) : super(key: key);

  @override
  _ConversationPanelState createState() => _ConversationPanelState();
}

class _ConversationPanelState extends State<ConversationPanel> {
  late Settings _settingsCopy;

  @override
  void initState() {
    super.initState();
    _settingsCopy = SettingsManager().settings;

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'theme-update' && this.mounted) {
        setState(() {});
      }
    });
  }

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
                  "Conversations",
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
                        child: Text("Customization".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )
                  ),
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.showDeliveryTimestamps.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.showDeliveryTimestamps.value,
                    title: "Show Delivery Timestamps",
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
                      _settingsCopy.recipientAsPlaceholder.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.recipientAsPlaceholder.value,
                    title: "Show Recipient (or Group Name) as Placeholder",
                    subtitle: "Changes the 'BlueBubbles' text in the message box to display the recipient name",
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
                      _settingsCopy.alwaysShowAvatars.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.alwaysShowAvatars.value,
                    title: "Show avatars in non-group chats",
                    subtitle: "Shows contact avatars in direct messages rather than just in group messages",
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
                      _settingsCopy.smartReply.value = val;
                      saveSettings();
                      setState(() {});
                    },
                    initialVal: _settingsCopy.smartReply.value,
                    title: "Show Smart Replies",
                    subtitle: "Shows smart reply suggestions above the message box",
                    backgroundColor: tileColor,
                  )),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Gestures"
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.autoOpenKeyboard.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.autoOpenKeyboard.value,
                    title: "Auto-open Keyboard",
                    subtitle: "Automatically open the keyboard when entering a chat",
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
                      _settingsCopy.swipeToCloseKeyboard.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.swipeToCloseKeyboard.value,
                    title: "Swipe Message Box to Close Keyboard",
                    subtitle: "Swipe down on the message box to hide the keyboard",
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
                      _settingsCopy.swipeToOpenKeyboard.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.swipeToOpenKeyboard.value,
                    title: "Swipe Message Box to Open Keyboard",
                    subtitle: "Swipe up on the message box to show the keyboard",
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
                      _settingsCopy.hideKeyboardOnScroll.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.hideKeyboardOnScroll.value,
                    title: "Hide Keyboard When Scrolling",
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
                      _settingsCopy.openKeyboardOnSTB.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.openKeyboardOnSTB.value,
                    title: "Open Keyboard After Tapping Scroll To Bottom",
                    subtitle: "Opens the keyboard after tapping the 'scroll to bottom' button",
                    backgroundColor: tileColor,
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Container(
                    color: tileColor,
                    child: Obx(() => SwitchListTile(
                      title: Text(
                        "Double-Tap Message for Details",
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                      value: _settingsCopy.doubleTapForDetails.value,
                      activeColor: Theme.of(context).primaryColor,
                      activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
                      inactiveTrackColor: tileColor == Theme.of(context).accentColor
                          ? Theme.of(context).backgroundColor.withOpacity(0.6) : Theme.of(context).accentColor.withOpacity(0.6),
                      inactiveThumbColor: tileColor == Theme.of(context).accentColor
                          ? Theme.of(context).backgroundColor : Theme.of(context).accentColor,
                      onChanged: (bool val) {
                        _settingsCopy.doubleTapForDetails.value = val;
                        if (val && _settingsCopy.enableQuickTapback.value) {
                          _settingsCopy.enableQuickTapback.value = false;
                        }
                        saveSettings();
                      },
                      subtitle: Text("Opens the message details popup when double tapping a message", style: Theme.of(context).textTheme.subtitle1),
                      tileColor: tileColor,
                    )),
                  ),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Container(
                    color: tileColor,
                    child: Obx(() => SwitchListTile(
                      title: Text(
                        "Double-Tap Message for Quick Tapback",
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                      value: _settingsCopy.enableQuickTapback.value,
                      activeColor: Theme.of(context).primaryColor,
                      activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
                      inactiveTrackColor: tileColor == Theme.of(context).accentColor
                          ? Theme.of(context).backgroundColor.withOpacity(0.6) : Theme.of(context).accentColor.withOpacity(0.6),
                      inactiveThumbColor: tileColor == Theme.of(context).accentColor
                          ? Theme.of(context).backgroundColor : Theme.of(context).accentColor,
                      onChanged: (bool val) {
                        _settingsCopy.enableQuickTapback.value = val;
                        if (val && _settingsCopy.doubleTapForDetails.value) {
                          _settingsCopy.doubleTapForDetails.value = false;
                        }
                        saveSettings();
                      },
                      subtitle: Text("Send a tapback of your choosing when double tapping a message", style: Theme.of(context).textTheme.subtitle1),
                      tileColor: tileColor,
                    )),
                  ),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Obx(() {
                    if (_settingsCopy.enableQuickTapback.value && _settingsCopy.skin.value == Skins.iOS)
                      return Container(
                        decoration: BoxDecoration(
                          color: tileColor,
                        ),
                        padding: EdgeInsets.only(left: 15),
                        child: Text("Select Quick Tapback"),
                      );
                    else return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (_settingsCopy.enableQuickTapback.value)
                      return SettingsOptions<String>(
                        title: "Quick Tapback",
                        options: ReactionTypes.toList(),
                        cupertinoCustomWidgets: [
                          Reaction(reactionType: ReactionTypes.LOVE).getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
                          Reaction(reactionType: ReactionTypes.LIKE).getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
                          Reaction(reactionType: ReactionTypes.DISLIKE).getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
                          Reaction(reactionType: ReactionTypes.LAUGH).getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
                          Reaction(reactionType: ReactionTypes.EMPHASIZE).getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
                          Reaction(reactionType: ReactionTypes.QUESTION).getSmallWidget(context, message: Message(isFromMe: true), isReactionPicker: true)!,
                        ],
                        initial: _settingsCopy.quickTapbackType.value,
                        textProcessing: (val) => val,
                        onChanged: (val) {
                          _settingsCopy.quickTapbackType.value = val;
                          saveSettings();
                        },
                        backgroundColor: tileColor,
                        secondaryColor: headerColor,
                      );
                    else return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (_settingsCopy.enableQuickTapback.value)
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
                      _settingsCopy.sendWithReturn.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.sendWithReturn.value,
                    title: "Send Message with Return Key",
                    subtitle: "Use the enter key as a send button",
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
    SettingsManager().saveSettings(_settingsCopy);
  }

  @override
  void dispose() {
    saveSettings();
    super.dispose();
  }
}