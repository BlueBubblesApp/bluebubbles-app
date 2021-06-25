import 'dart:ui';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConvoSettings extends StatefulWidget {
  ConvoSettings({Key key}) : super(key: key);

  @override
  _ConvoSettingsState createState() => _ConvoSettingsState();
}

class _ConvoSettingsState extends State<ConvoSettings> {
  Settings _settingsCopy;
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
        systemNavigationBarColor: Theme.of(context).backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(Get.mediaQuery.size.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_back_ios : Icons.arrow_back,
                      color: Theme.of(context).primaryColor),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
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
                      _settingsCopy.doubleTapForDetails = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.doubleTapForDetails,
                    title: "Double-Tap Message for Details",
                  ),
                  // SettingsSwitch(
                  //   onChanged: (bool val) {
                  //     _settingsCopy.sendTypingIndicators = val;
                  //   },
                  //   initialVal: _settingsCopy.sendTypingIndicators,
                  //   title: "Send typing indicators (BlueBubblesHelper ONLY)",
                  // ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.smartReply = val;
                      saveSettings();
                      setState(() {});
                    },
                    initialVal: _settingsCopy.smartReply,
                    title: "Smart Replies",
                  ),
                  if (_settingsCopy.smartReply)
                    SettingsSlider(
                        text: "Smart Reply Sample Size",
                        startingVal: _settingsCopy.smartReplySampleSize.toDouble(),
                        update: (double val) {
                          _settingsCopy.smartReplySampleSize = val.toInt();
                        },
                        formatValue: ((double val) => val.toStringAsFixed(2)),
                        min: 1,
                        max: 10,
                        divisions: 9),
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
