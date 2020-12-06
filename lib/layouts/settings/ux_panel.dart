import 'dart:ui';

import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

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
    if (gotBrightness) return;
    if (context == null) {
      brightness = Brightness.light;
      gotBrightness = true;
      return;
    }

    bool isDark = Theme.of(context).backgroundColor.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
  }

  @override
  Widget build(BuildContext context) {
    loadBrightness();

    return Scaffold(
      // extendBodyBehindAppBar: true,
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
                icon: Icon(Icons.arrow_back_ios,
                    color: Theme.of(context).primaryColor),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
              title: Text(
                "User Experience",
                style: Theme.of(context).textTheme.headline1,
              ),
            ),
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          ),
        ),
      ),
      body: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(
          parent: CustomBouncingScrollPhysics(),
        ),
        slivers: <Widget>[
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                Container(padding: EdgeInsets.only(top: 5.0)),
                SettingsSwitch(
                  onChanged: (bool val) {
                    _settingsCopy.hideTextPreviews = val;
                  },
                  initialVal: _settingsCopy.hideTextPreviews,
                  title: "Hide Text Previews (in notifications)",
                ),
                SettingsSwitch(
                  onChanged: (bool val) {
                    _settingsCopy.autoOpenKeyboard = val;
                  },
                  initialVal: _settingsCopy.autoOpenKeyboard,
                  title: "Auto-open Keyboard",
                ),
                SettingsSwitch(
                  onChanged: (bool val) {
                    _settingsCopy.sendTypingIndicators = val;
                  },
                  initialVal: _settingsCopy.sendTypingIndicators,
                  title: "Send typing indicators (BlueBubblesHelper ONLY)",
                ),
                SettingsSwitch(
                  onChanged: (bool val) {
                    _settingsCopy.sendWithReturn = val;
                  },
                  initialVal: _settingsCopy.sendWithReturn,
                  title: "Send Message with Return Key",
                ),
                SettingsSwitch(
                  onChanged: (bool val) {
                    _settingsCopy.lowMemoryMode = val;
                  },
                  initialVal: _settingsCopy.lowMemoryMode,
                  title: "Low Memory Mode",
                ),
                SettingsSwitch(
                  onChanged: (bool val) {
                    _settingsCopy.showIncrementalSync = val;
                  },
                  initialVal: _settingsCopy.showIncrementalSync,
                  title: "Notify when incremental sync complete",
                ),
                SettingsSlider(
                    text: "Scroll Speed Multiplier",
                    startingVal: _settingsCopy.scrollVelocity,
                    update: (double val) {
                      _settingsCopy.scrollVelocity =
                          double.parse(val.toStringAsFixed(2));
                    },
                    formatValue: ((double val) => val.toStringAsFixed(2)),
                    min: 0.20,
                    max: 2,
                    divisions: 18),
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
