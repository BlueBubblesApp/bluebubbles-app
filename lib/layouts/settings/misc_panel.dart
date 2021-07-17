import 'dart:ui';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MiscPanel extends StatefulWidget {
  MiscPanel({Key? key}) : super(key: key);

  @override
  _MiscPanelState createState() => _MiscPanelState();
}

class _MiscPanelState extends State<MiscPanel> {
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
                  "Miscellaneous",
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
                        child: Text("Notifications".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )
                  ),
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.hideTextPreviews.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.hideTextPreviews.value,
                    title: "Hide Message Text",
                    subtitle: "Replaces message text with 'iMessage' in notifications",
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
                      _settingsCopy.showIncrementalSync.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.showIncrementalSync.value,
                    title: "Notify when incremental sync complete",
                    subtitle: "Show a snackbar whenever a message sync is completed",
                    backgroundColor: tileColor,
                  )),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Speed & Responsiveness"
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.lowMemoryMode.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.lowMemoryMode.value,
                    title: "Low Memory Mode",
                    subtitle: "Reduces background processes and deletes cached storage items to improve performance on lower-end devices",
                    backgroundColor: tileColor,
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
                      return SettingsTile(
                        title: "Scroll Speed Multiplier",
                        subtitle: "Controls how fast scrolling occurs",
                        backgroundColor: tileColor,
                      );
                    else return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.skin.value == Skins.iOS)
                      return SettingsSlider(
                          text: "Scroll Speed Multiplier",
                          startingVal: _settingsCopy.scrollVelocity.value,
                          update: (double val) {
                            _settingsCopy.scrollVelocity.value = double.parse(val.toStringAsFixed(2));
                          },
                          formatValue: ((double val) => val.toStringAsFixed(2)),
                          backgroundColor: tileColor,
                          min: 0.20,
                          max: 1,
                          divisions: 8
                      );
                    else return SizedBox.shrink();
                  }),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Other"
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.sendDelay.value = val ? 3 : 0;
                      saveSettings();
                      setState(() {});
                    },
                    initialVal: !isNullOrZero(_settingsCopy.sendDelay.value),
                    title: "Send Delay",
                    backgroundColor: tileColor,
                  )),
                  Obx(() {
                    if (!isNullOrZero(SettingsManager().settings.sendDelay.value))
                      return SettingsSlider(
                          text: "Set send delay",
                          startingVal: _settingsCopy.sendDelay.toDouble(),
                          update: (double val) {
                            _settingsCopy.sendDelay.value = val.toInt();
                          },
                          formatValue: ((double val) => val.toStringAsFixed(0) + " sec"),
                          backgroundColor: tileColor,
                          min: 1,
                          max: 10,
                          divisions: 9
                      );
                    else return SizedBox.shrink();
                  }),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.use24HrFormat.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.use24HrFormat.value,
                    title: "Use 24 Hour Format for Times",
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
