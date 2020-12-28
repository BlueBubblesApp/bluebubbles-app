import 'dart:async';
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/theming/theming_panel.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter/material.dart';

class ThemePanel extends StatefulWidget {
  ThemePanel({Key key}) : super(key: key);

  @override
  _ThemePanelState createState() => _ThemePanelState();
}

class _ThemePanelState extends State<ThemePanel> {
  Settings _settingsCopy;
  List<DisplayMode> modes;
  DisplayMode currentMode;
  Brightness brightness;
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

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    modes = await FlutterDisplayMode.supported;
    currentMode = await _settingsCopy.getDisplayMode();
    setState(() {});
  }

  void loadBrightness() {
    if (gotBrightness) return;
    if (context == null) {
      brightness = Brightness.light;
      gotBrightness = true;
      return;
    }

    bool isDark = Theme.of(context).accentColor.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
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
                  icon: Icon(SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_back_ios : Icons.arrow_back,
                      color: Theme.of(context).primaryColor),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
                title: Text(
                  "Theming & Styles",
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
                  SettingsOptions<AdaptiveThemeMode>(
                    initial: AdaptiveTheme.of(context).mode,
                    onChanged: (val) {
                      AdaptiveTheme.of(context).setThemeMode(val);

                      // This needs to be on a delay so the background color has time to change
                      Timer(Duration(seconds: 1),
                          () => EventDispatcher().emit('theme-update', null));
                    },
                    options: AdaptiveThemeMode.values,
                    textProcessing: (dynamic val) =>
                        val.toString().split(".").last,
                    title: "App Theme",
                    showDivider: false,
                  ),
                  SettingsTile(
                    title: "Theming",
                    trailing: Icon(Icons.arrow_forward_ios,
                        color: Theme.of(context).primaryColor),
                    onTap: () async {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ThemingPanel(),
                        ),
                      );
                    },
                  ),
                  SettingsOptions<Skins>(
                    initial: _settingsCopy.skin,
                    onChanged: (val) {
                      _settingsCopy.skin = val;
                      if (val == Skins.Material) {
                        _settingsCopy.hideDividers = true;
                      } else {
                        _settingsCopy.hideDividers = false;
                      }
                      setState(() {});
                    },
                    options: Skins.values,
                    textProcessing: (dynamic val) =>
                        val.toString().split(".").last,
                    title: "App Skin",
                    showDivider: false,
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.hideDividers = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.hideDividers,
                    title: "Hide Dividers",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.colorfulAvatars = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.colorfulAvatars,
                    title: "Colorful Avatars",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.colorfulBubbles = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.colorfulBubbles,
                    title: "Colorful Bubbles",
                  ),
                  // For whatever fucking reason, this needs to be down here, otherwise all of the switch values are false
                  if (currentMode != null && modes != null)
                    SettingsOptions<DisplayMode>(
                      initial: currentMode,
                      showDivider: false,
                      onChanged: (val) async {
                        currentMode = val;
                        _settingsCopy.displayMode = currentMode.id;
                      },
                      options: modes,
                      textProcessing: (dynamic val) => val.toString(),
                      title: "Display",
                    ),
                  // SettingsOptions<String>(
                  //   initial: _settingsCopy.emojiFontFamily == null
                  //       ? "System"
                  //       : fontFamilyToString[_settingsCopy.emojiFontFamily],
                  //   onChanged: (val) {
                  //     _settingsCopy.emojiFontFamily = stringToFontFamily[val];
                  //   },
                  //   options: stringToFontFamily.keys.toList(),
                  //   textProcessing: (dynamic val) => val,
                  //   title: "Emoji Style",
                  //   showDivider: false,
                  // ),
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
