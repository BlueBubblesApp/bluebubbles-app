import 'dart:ui';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/messages_view_ux_panel.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UXPanel extends StatefulWidget {
  UXPanel({Key key}) : super(key: key);

  @override
  _UXPanelState createState() => _UXPanelState();
}

class _UXPanelState extends State<UXPanel> {
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
    Color now = Get.theme.backgroundColor;
    bool themeChanged = previousBackgroundColor == null || previousBackgroundColor != now;
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
        systemNavigationBarColor: Get.theme.backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: Get.theme.backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(Get.mediaQuery.size.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: brightness,
                toolbarHeight: 100.0,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_back_ios : Icons.arrow_back,
                      color: Get.theme.primaryColor),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                backgroundColor: Get.theme.accentColor.withOpacity(0.5),
                title: Text(
                  "User Experience",
                  style: Get.theme.textTheme.headline1,
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
                  SettingsTile(
                    title: "Conversation Settings",
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ConvoSettings(),
                        ),
                      );
                    },
                    trailing: Icon(
                      SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_forward_ios : Icons.arrow_forward,
                      color: Get.theme.primaryColor,
                    ),
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.showConnectionIndicator = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.showConnectionIndicator,
                    title: "Show Connection Indicator",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.showSyncIndicator = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.showSyncIndicator,
                    title: "Show Sync Indicator in Chat List",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.colorblindMode = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.colorblindMode,
                    title: "Colorblind Mode",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.filteredChatList = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.filteredChatList,
                    title: "Filtered Chat List",
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
                      _settingsCopy.hideTextPreviews = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.hideTextPreviews,
                    title: "Hide Text Previews (in notifications)",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.preCachePreviewImages = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.preCachePreviewImages,
                    title: "Pre-Cache Preview Images",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.lowMemoryMode = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.lowMemoryMode,
                    title: "Low Memory Mode",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.showIncrementalSync = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.showIncrementalSync,
                    title: "Notify when incremental sync complete",
                  ),
                  if (SettingsManager().settings.skin == Skins.IOS)
                    SettingsSlider(
                        text: "Scroll Speed Multiplier",
                        startingVal: _settingsCopy.scrollVelocity,
                        update: (double val) {
                          _settingsCopy.scrollVelocity = double.parse(val.toStringAsFixed(2));
                        },
                        formatValue: ((double val) => val.toStringAsFixed(2)),
                        min: 0.20,
                        max: 1,
                        divisions: 8),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.sendDelay = val ? 3 : 0;
                      saveSettings();
                      setState(() {});
                    },
                    initialVal: !isNullOrZero(_settingsCopy.sendDelay),
                    title: "Send Delay",
                  ),
                  if (!isNullOrZero(SettingsManager().settings.sendDelay))
                    SettingsSlider(
                        text: "Send Delay (Seconds)",
                        startingVal: _settingsCopy.sendDelay.toDouble(),
                        update: (double val) {
                          _settingsCopy.sendDelay = val.toInt();
                        },
                        formatValue: ((double val) => val.toStringAsFixed(2)),
                        min: 1,
                        max: 10,
                        divisions: 9),
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
