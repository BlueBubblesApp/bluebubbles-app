import 'dart:ui';

import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:bluebubbles/helpers/contstants.dart';
import 'package:flutter/material.dart';

class PrivateAPIPanel extends StatefulWidget {
  PrivateAPIPanel({Key key}) : super(key: key);

  @override
  _PrivateAPIPanelState createState() => _PrivateAPIPanelState();
}

class _PrivateAPIPanelState extends State<PrivateAPIPanel> {
  Settings _settingsCopy;
  Brightness brightness;
  Color previousBackgroundColor;
  bool gotBrightness = false;
  bool enablePrivateAPI = false;

  @override
  void initState() {
    super.initState();
    _settingsCopy = SettingsManager().settings;
    enablePrivateAPI = _settingsCopy.enablePrivateAPI;

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

    List<Widget> privateWidgets = [];
    print(enablePrivateAPI);
    if (enablePrivateAPI) {
      privateWidgets.addAll([
        SettingsSwitch(
          onChanged: (bool val) {
            _settingsCopy.sendTypingIndicators = val;
            saveSettings();
          },
          initialVal: _settingsCopy.sendTypingIndicators,
          title: "Send Typing Indicators",
        ),
      ]);
    }

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
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  Container(padding: EdgeInsets.only(top: 5.0)),
                  SettingsTile(
                      title: "Please read before using these features!",
                      subTitle:
                          ("Private API features are only available to those running the nightly version of the server. " +
                              "If you are not running the nightly version, you will not be able to utiulize these features, " +
                              "even if you have it enabled.")),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.enablePrivateAPI = val;
                      if (this.mounted) {
                        setState(() {
                          enablePrivateAPI = val;
                        });
                      }

                      saveSettings();
                    },
                    initialVal: _settingsCopy.enablePrivateAPI,
                    title: "Enable Private API Features",
                  ),
                  ...privateWidgets
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
