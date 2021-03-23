import 'dart:ui';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:flutter/material.dart';

class ConvoListSettings extends StatefulWidget {
  ConvoListSettings({Key key}) : super(key: key);

  @override
  _ConvoListSettingsState createState() => _ConvoListSettingsState();
}

class _ConvoListSettingsState extends State<ConvoListSettings> {
  Settings _settingsCopy;
  bool needToReconnect = false;
  bool showUrl = false;
  Brightness brightness;
  Color previousBackgroundColor;
  bool gotBrightness = false;

  @override
  void initState() {
    super.initState();
    _settingsCopy = SettingsManager().settings;

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'theme-update' && this.mounted) {
        setState(() {
          gotBrightness = false;
        });
      }
    });
  }

  void loadBrightness() {
    Color now = Theme.of(context).backgroundColor;
    bool themeChanged =
        previousBackgroundColor == null || previousBackgroundColor != now;
    if (!themeChanged && gotBrightness) return;

    previousBackgroundColor = now;
    if (this.context == null) {
      brightness = Brightness.light;
      gotBrightness = true;
      return;
    }

    bool isDark = now.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
    if (this.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    loadBrightness();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(MediaQuery.of(context).size.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: brightness,
                toolbarHeight: 100.0,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                      SettingsManager().settings.skin == Skins.IOS
                          ? Icons.arrow_back_ios
                          : Icons.arrow_back,
                      color: Theme.of(context).primaryColor),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
                title: Text(
                  "Conversation List Settings",
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
                  if (SettingsManager().settings.skin == Skins.IOS)
                    SettingsSwitch(
                      onChanged: (bool val) {
                        _settingsCopy.swipeMenuShowArchive = val;
                        saveSettings();
                      },
                      initialVal: _settingsCopy.swipeMenuShowArchive,
                      title: "Show Archive option in slide menu",
                    ),
                  if (SettingsManager().settings.skin == Skins.IOS)
                    SettingsSwitch(
                      onChanged: (bool val) {
                        _settingsCopy.swipeMenuShowPin = val;
                        saveSettings();
                      },
                      initialVal: _settingsCopy.swipeMenuShowPin,
                      title: "Show Pin option in slide menu",
                    ),
                  if (SettingsManager().settings.skin == Skins.IOS)
                    SettingsSwitch(
                      onChanged: (bool val) {
                        _settingsCopy.swipeMenuShowHideAlerts = val;
                        saveSettings();
                      },
                      initialVal: _settingsCopy.swipeMenuShowHideAlerts,
                      title: "Show Hide Alerts option in slide menu",
                    ),
                  if (SettingsManager().settings.skin == Skins.IOS)
                    SettingsSwitch(
                      onChanged: (bool val) {
                        _settingsCopy.swipeMenuShowMarkUnread = val;
                        saveSettings();
                      },
                      initialVal: _settingsCopy.swipeMenuShowMarkUnread,
                      title: "Show Mark Unread option in slide menu",
                    ),
                  if (SettingsManager().settings.skin == Skins.Samsung ||
                      SettingsManager().settings.skin == Skins.Material)
                    SettingsSwitch(
                      onChanged: (bool val) {
                        _settingsCopy.swipableConversationTiles = val;
                        saveSettings();
                      },
                      initialVal: _settingsCopy.swipableConversationTiles,
                      title: "Swipe Actions for Conversation Tiles",
                    ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.moveChatCreatorToHeader = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.moveChatCreatorToHeader,
                    title: "Move Chat Creator Button to Header",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.showConnectionIndicator = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.showConnectionIndicator,
                    title: "Show Connection Indicator in Chat List",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.showSyncIndicator = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.showSyncIndicator,
                    title: "Show Sync Indicator in Chat List",
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
