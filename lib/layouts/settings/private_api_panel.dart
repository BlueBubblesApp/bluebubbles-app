import 'dart:ui';

import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivateAPIPanel extends StatefulWidget {
  PrivateAPIPanel({Key key}) : super(key: key);

  @override
  _PrivateAPIPanelState createState() => _PrivateAPIPanelState();
}

class _PrivateAPIPanelState extends State<PrivateAPIPanel> {
  Settings _settingsCopy;
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
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> privateWidgets = [];
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
        SettingsSwitch(
          onChanged: (bool val) {
            _settingsCopy.privateMarkChatAsRead = val;
            saveSettings(updateState: true);
          },
          initialVal: _settingsCopy.privateMarkChatAsRead,
          title: "Mark Chats as Read / Send Read Receipts",
        ),
        if (!_settingsCopy.privateMarkChatAsRead)
          SettingsSwitch(
            onChanged: (bool val) {
              _settingsCopy.privateManualMarkAsRead = val;
              saveSettings();
            },
            initialVal: _settingsCopy.privateManualMarkAsRead,
            title: "Show Manually Mark Chat as Read Button",
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
          preferredSize: Size(Get.mediaQuery.size.width, 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
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
                  SettingsTile(
                      title: "",
                      subTitle: ("Private API features give you the ability to send tapbacks, send read receipts, and receive typing indicators. " +
                          "These features are only available to those running the nightly version of the Server. " +
                          "If you are not running the nightly version of the Server, you will not be able to utilize these features, " +
                          "even if you have it enabled here. If you would like to find out how to setup these features, please visit " +
                          "the link below")),
                  SettingsTile(
                    title: "How to setup Private API features",
                    onTap: () {
                      MethodChannelInterface().invokeMethod("open-link", {
                        "link": "https://github.com/BlueBubblesApp/BlueBubbles-Server/wiki/Using-Private-API-Features"
                      });
                    },
                    trailing: Icon(
                      Icons.privacy_tip_rounded,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
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

  void saveSettings({bool updateState = false}) async {
    await SettingsManager().saveSettings(_settingsCopy);
    if (updateState && this.mounted) {
      this.setState(() {});
    }
  }

  @override
  void dispose() {
    saveSettings();
    super.dispose();
  }
}
