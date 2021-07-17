import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/socket_manager.dart';
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
  PrivateAPIPanel({Key? key}) : super(key: key);

  @override
  _PrivateAPIPanelState createState() => _PrivateAPIPanelState();
}

class _PrivateAPIPanelState extends State<PrivateAPIPanel> {
  late Settings _settingsCopy;
  int? macOSVersionNumber;
  String? macOSVersion;

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

    SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
      if (mounted) {
        setState(() {
          macOSVersionNumber = int.tryParse(res['data']['os_version'].toString().split(".")[0]);
          macOSVersion = res['data']['os_version'];
        });
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
            Obx(() => SliverList(
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
                        child: Text("Private API".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )
                  ),
                  Container(
                      decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                        color: tileColor,
                        border: Border(
                            bottom: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                        ),
                      ) : BoxDecoration(
                        color: tileColor,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: "Private API features give you the ability to send tapbacks, send read receipts, and see typing indicators."),
                              TextSpan(text: "\n\n"),
                              TextSpan(text: "These features are only available to those running the nightly version of the server on Mac OS 10.15 and under."),
                              TextSpan(text: "\n\n"),
                              TextSpan(text: "Please note that servers running Mac OS 11+ "),
                              TextSpan(text: "are not supported.", style: TextStyle(fontStyle: FontStyle.italic)),
                              TextSpan(text: "\n\n"),
                              TextSpan(text: "You must be using the nightly version of the server for these features to function, regardless of whether you enable them here."),
                            ]
                          ),
                        ),
                      )
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "Set up Private API Features",
                    subtitle: "View instructions on how to set up these features",
                    onTap: () async {
                      MethodChannelInterface().invokeMethod("open-link", {
                        "link": "https://github.com/BlueBubblesApp/BlueBubbles-Server/wiki/Using-Private-API-Features"
                      });
                    },
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.checkmark_shield,
                      materialIcon: Icons.privacy_tip,
                    ),
                  ),
                  ((macOSVersionNumber ??10) < 11) ?
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ) : Container(),
                  (macOSVersionNumber ?? 10) < 11 ? SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.enablePrivateAPI.value = val;
                      saveSettings();
                    },
                    initialVal: _settingsCopy.enablePrivateAPI.value,
                    title: "Enable Private API Features",
                  ) : Container(
                      decoration: BoxDecoration(
                        color: tileColor,
                        border: Border(
                            top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                        child: RichText(
                          text: TextSpan(
                              children: [
                                TextSpan(text: "Private API features are not supported on your server's macOS Version."),
                                TextSpan(text: "\n\n"),
                                TextSpan(text: "Current: ${macOSVersion ?? "Unknown"}"),
                                TextSpan(text: "\n\n"),
                                TextSpan(text: "Required: 10.15.7 and under"),
                              ]
                          ),
                        ),
                      )
                  ),
                  if (SettingsManager().settings.enablePrivateAPI.value)
                    ...[
                      SettingsHeader(
                          headerColor: headerColor,
                          tileColor: tileColor,
                          iosSubtitle: iosSubtitle,
                          materialSubtitle: materialSubtitle,
                          text: "Private API Settings"
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          _settingsCopy.privateSendTypingIndicators.value = val;
                          saveSettings();
                        },
                        initialVal: _settingsCopy.privateSendTypingIndicators.value,
                        title: "Send Typing Indicators",
                        subtitle: "Sends typing indicators to other iMessage users",
                        backgroundColor: tileColor,
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          _settingsCopy.privateMarkChatAsRead.value = val;
                          saveSettings(updateState: true);
                        },
                        initialVal: _settingsCopy.privateMarkChatAsRead.value,
                        title: "Mark Chats as Read / Send Read Receipts",
                        subtitle: "Marks chats read in the iMessage app on your server and sends read receipts to other iMessage users",
                        backgroundColor: tileColor,
                      ),
                      if (!_settingsCopy.privateMarkChatAsRead.value)
                        SettingsSwitch(
                          onChanged: (bool val) {
                            _settingsCopy.privateManualMarkAsRead.value = val;
                            saveSettings();
                          },
                          initialVal: _settingsCopy.privateManualMarkAsRead.value,
                          title: "Show Manually Mark Chat as Read Button",
                          backgroundColor: tileColor,
                        ),
                    ],
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
            )),
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
