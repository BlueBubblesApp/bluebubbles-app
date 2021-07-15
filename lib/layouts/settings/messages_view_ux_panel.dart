import 'dart:ui';

import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ConvoSettings extends StatefulWidget {
  ConvoSettings({Key? key}) : super(key: key);

  @override
  _ConvoSettingsState createState() => _ConvoSettingsState();
}

class _ConvoSettingsState extends State<ConvoSettings> {
  late Settings _settingsCopy;
  bool needToReconnect = false;
  bool showUrl = false;

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(context.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
                title: Text(
                  "Conversation Settings",
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
                  Container(padding: EdgeInsets.only(top: 5.0)),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.showDeliveryTimestamps = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.showDeliveryTimestamps,
                    title: "Show Delivery Timestamps",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.autoOpenKeyboard = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.autoOpenKeyboard,
                    title: "Auto-open Keyboard",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.swipeToCloseKeyboard = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.swipeToCloseKeyboard,
                    title: "Swipe TextField to Close Keyboard",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.swipeToOpenKeyboard = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.swipeToOpenKeyboard,
                    title: "Swipe TextField to Open Keyboard",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.hideKeyboardOnScroll = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.hideKeyboardOnScroll,
                    title: "Hide Keyboard on Scroll",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.openKeyboardOnSTB = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.openKeyboardOnSTB,
                    title: "Open Keyboard on Scrolling to Bottom Tap",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.recipientAsPlaceholder = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.recipientAsPlaceholder,
                    title: "Show Recipient (or Group Name) as Placeholder",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.alwaysShowAvatars = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.alwaysShowAvatars,
                    title: "Show avatars in non-group chats",
                  ),
                  SwitchListTile(
                    title: Text(
                      "Double-Tap Message for Details",
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                    value: _settingsCopy.doubleTapForDetails,
                    activeColor: Theme.of(context).primaryColor,
                    activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
                    inactiveTrackColor: Theme.of(context).accentColor.withOpacity(0.6),
                    inactiveThumbColor: Theme.of(context).accentColor,
                    onChanged: (bool val) {
                      _settingsCopy.doubleTapForDetails = val;
                      if (val && _settingsCopy.enableQuickTapback) {
                        _settingsCopy.enableQuickTapback = false;
                      }
                      saveSettings();
                      setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      "Double-Tap Message for Quick Tapback",
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                    value: _settingsCopy.enableQuickTapback,
                    activeColor: Theme.of(context).primaryColor,
                    activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
                    inactiveTrackColor: Theme.of(context).accentColor.withOpacity(0.6),
                    inactiveThumbColor: Theme.of(context).accentColor,
                    onChanged: (bool val) {
                      _settingsCopy.enableQuickTapback = val;
                      if (val && _settingsCopy.doubleTapForDetails) {
                        _settingsCopy.doubleTapForDetails = false;
                      }
                      saveSettings();
                      setState(() {});
                    },
                  ),
                  if (_settingsCopy.enableQuickTapback)
                    SettingsOptions<String>(
                      title: "Quick Tapback",
                      options: ReactionTypes.toList(),
                      initial: _settingsCopy.quickTapbackType,
                      textProcessing: (val) => val,
                      onChanged: (val) {
                        _settingsCopy.quickTapbackType = val;
                        saveSettings();
                      },
                    ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.smartReply = val;
                      saveSettings();
                      setState(() {});
                    },
                    initialVal: _settingsCopy.smartReply,
                    title: "Smart Replies",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.sendWithReturn = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.sendWithReturn,
                    title: "Send Message with Return Key",
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
