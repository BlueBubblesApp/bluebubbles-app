import 'dart:convert';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import "package:bluebubbles/helpers/string_extension.dart";
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/about_panel.dart';
import 'package:bluebubbles/layouts/settings/attachment_panel.dart';
import 'package:bluebubbles/layouts/settings/private_api_panel.dart';
import 'package:bluebubbles/layouts/settings/redacted_mode_panel.dart';
import 'package:bluebubbles/layouts/settings/server_management_panel.dart';
import 'package:bluebubbles/layouts/settings/theme_panel.dart';
import 'package:bluebubbles/layouts/settings/ux_panel.dart';
import 'package:bluebubbles/layouts/setup/qr_code_scanner.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoTextField.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../setup/qr_code_scanner.dart';

List disconnectedStates = [SocketState.DISCONNECTED, SocketState.ERROR, SocketState.FAILED];

class SettingsPanel extends StatefulWidget {
  SettingsPanel({Key key}) : super(key: key);

  @override
  _SettingsPanelState createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  Settings _settingsCopy;
  FCMData _fcmDataCopy;
  bool needToReconnect = false;
  bool showUrl = false;
  int lastRestart;

  @override
  void initState() {
    super.initState();
    _settingsCopy = SettingsManager().settings;
    _fcmDataCopy = SettingsManager().fcmData;

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
    Widget nextIcon = Icon(
      SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_forward_ios : Icons.arrow_forward,
      color: Theme.of(context).primaryColor,
    );

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
                  "Settings",
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
                  StreamBuilder(
                      stream: SocketManager().connectionStateStream,
                      builder: (context, AsyncSnapshot<SocketState> snapshot) {
                        SocketState connectionStatus;
                        if (snapshot.hasData) {
                          connectionStatus = snapshot.data;
                        } else {
                          connectionStatus = SocketManager().state;
                        }
                        String subtitle;

                        switch (connectionStatus) {
                          case SocketState.CONNECTED:
                            if (showUrl) {
                              subtitle = "Connected (${this._settingsCopy.serverAddress})";
                            } else {
                              subtitle = "Connected (Tap to view URL)";
                            }
                            break;
                          case SocketState.DISCONNECTED:
                            subtitle = "Disconnected (Tap to restart Server)";
                            break;
                          case SocketState.ERROR:
                            subtitle = "Error (Tap to restart Server)";
                            break;
                          case SocketState.CONNECTING:
                            subtitle = "Connecting...";
                            break;
                          case SocketState.FAILED:
                            subtitle = "Failed to connect (Tap to restart Server)";
                            break;
                        }

                        return SettingsTile(
                          title: "Connection Status",
                          subTitle: subtitle,
                          onTap: () async {
                            // If we are disconnected, tap to restart server
                            if (disconnectedStates.contains(connectionStatus)) {
                              // Prevent restarting more than once per 30 seconds
                              int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                              if (lastRestart != null && now - lastRestart < 1000 * 30) return;

                              // Restart the server
                              MethodChannelInterface().invokeMethod(
                                  "set-next-restart", {"value": DateTime.now().toUtc().millisecondsSinceEpoch});

                              lastRestart = now;
                            }

                            // If we are connected, tap to show the URL
                            if ([SocketState.CONNECTED].contains(connectionStatus)) {
                              if (this.mounted) {
                                setState(() {
                                  showUrl = !showUrl;
                                });
                              }
                            }
                          },
                          onLongPress: () {
                            Clipboard.setData(new ClipboardData(text: _settingsCopy.serverAddress));
                            showSnackbar('Copied', "Address copied to clipboard");
                          },
                          trailing: getIndicatorIcon(connectionStatus),
                        );
                      }),
                  SettingsTile(
                    title: "Re-configure with MacOS Server",
                    trailing: Icon(Icons.camera, color: Theme.of(context).primaryColor.withAlpha(200)),
                    onTap: () async {
                      var fcmData;
                      try {
                        fcmData = jsonDecode(
                          await Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (BuildContext context) {
                                return QRCodeScanner();
                              },
                            ),
                          ),
                        );
                      } catch (e) {
                        return;
                      }
                      if (fcmData != null) {
                        _fcmDataCopy = FCMData(
                          projectID: fcmData[2],
                          storageBucket: fcmData[3],
                          apiKey: fcmData[4],
                          firebaseURL: fcmData[5],
                          clientID: fcmData[6],
                          applicationID: fcmData[7],
                        );
                        _settingsCopy.guidAuthKey = fcmData[0];
                        _settingsCopy.serverAddress = getServerAddress(address: fcmData[1]);

                        SettingsManager().saveSettings(_settingsCopy);
                        SettingsManager().saveFCMData(_fcmDataCopy);
                        SocketManager().authFCM();
                      }
                    },
                  ),
                  // SettingsTile(
                  //   title: "Message Scheduling",
                  //   trailing: Icon(Icons.arrow_forward_ios,
                  //       color: Theme.of(context).primaryColor),
                  //   onTap: () async {
                  //     Navigator.of(context).push(
                  //       CupertinoPageRoute(
                  //         builder: (context) => SchedulingPanel(),
                  //       ),
                  //     );
                  //   },
                  // ),
                  // SettingsTile(
                  //   title: "Search",
                  //   trailing: Icon(Icons.arrow_forward_ios,
                  //       color: Theme.of(context).primaryColor),
                  //   onTap: () async {
                  //     Navigator.of(context).push(
                  //       CupertinoPageRoute(
                  //         builder: (context) => SearchView(),
                  //       ),
                  //     );
                  //   },
                  // ),
                  SettingsTile(
                    title: "Attachment Settings",
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => AttachmentPanel(),
                        ),
                      );
                    },
                    trailing: nextIcon,
                  ),
                  SettingsTile(
                    title: "Theme Settings",
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ThemePanel(),
                        ),
                      );
                    },
                    trailing: nextIcon,
                  ),
                  SettingsTile(
                    title: "User Experience Settings",
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => UXPanel(),
                        ),
                      );
                    },
                    trailing: nextIcon,
                  ),
                  SettingsTile(
                    title: "Private API Features",
                    trailing: Icon(
                        SettingsManager().settings.skin == Skins.IOS ? Icons.arrow_forward_ios : Icons.arrow_forward,
                        color: Theme.of(context).primaryColor),
                    onTap: () async {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => PrivateAPIPanel(),
                        ),
                      );
                    },
                  ),
                  SettingsTile(
                    title: "Redacted Mode",
                    trailing: nextIcon,
                    onTap: () async {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => RedactedModePanel(),
                        ),
                      );
                    },
                  ),
                  SettingsTile(
                    title: "Server Management",
                    trailing: nextIcon,
                    onTap: () async {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ServerManagementPanel(),
                        ),
                      );
                    },
                  ),
                  SettingsTile(
                    title: "About & Links",
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => AboutPanel(),
                        ),
                      );
                    },
                    trailing: nextIcon,
                  ),
                  SettingsTile(
                    title: "Join Our Discord",
                    onTap: () {
                      MethodChannelInterface().invokeMethod("open-link", {"link": "https://discord.gg/hbx7EhNFjp"});
                    },
                    trailing: SvgPicture.asset(
                      "assets/icon/discord.svg",
                      color: HexColor("#7289DA"),
                      alignment: Alignment.centerRight,
                      width: 30,
                    ),
                  ),
                  SettingsTile(
                    title: "Support the Developers!",
                    onTap: () {
                      MethodChannelInterface().invokeMethod("open-link", {"link": "https://bluebubbles.app/donate/"});
                    },
                    trailing: Icon(
                      Icons.attach_money,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SettingsTile(
                    onTap: () {
                      showDialog(
                        barrierDismissible: false,
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text(
                              "Are you sure?",
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                            backgroundColor: Theme.of(context).backgroundColor,
                            actions: <Widget>[
                              FlatButton(
                                child: Text("Yes"),
                                onPressed: () async {
                                  await DBProvider.deleteDB();
                                  await SettingsManager().resetConnection();

                                  SocketManager().finishedSetup.sink.add(false);
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                },
                              ),
                              FlatButton(
                                child: Text("Cancel"),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                    title: "Reset DB",
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
    if (needToReconnect) {
      SocketManager().startSocketIO(forceNewConnection: true);
    }
  }

  @override
  void dispose() {
    saveSettings();
    super.dispose();
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({Key key, this.onTap, this.onLongPress, this.title, this.trailing, this.subTitle})
      : super(key: key);

  final Function onTap;
  final Function onLongPress;
  final String subTitle;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).backgroundColor,
      child: InkWell(
        onLongPress: this.onLongPress,
        onTap: this.onTap,
        child: Column(
          children: <Widget>[
            ListTile(
              title: Text(
                this.title,
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: this.trailing,
              subtitle: subTitle != null
                  ? Text(
                      subTitle,
                      style: Theme.of(context).textTheme.subtitle1,
                    )
                  : null,
            ),
            Divider(
              color: Theme.of(context).accentColor.withOpacity(0.5),
              thickness: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsTextField extends StatelessWidget {
  const SettingsTextField(
      {Key key,
      this.onTap,
      this.title,
      this.trailing,
      @required this.controller,
      this.placeholder,
      this.maxLines = 14,
      this.keyboardType = TextInputType.multiline,
      this.inputFormatters = const []})
      : super(key: key);

  final TextEditingController controller;
  final Function onTap;
  final String title;
  final String placeholder;
  final Widget trailing;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).backgroundColor,
      child: InkWell(
        onTap: this.onTap,
        child: Column(
          children: <Widget>[
            ListTile(
              title: Text(
                this.title,
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: this.trailing,
              subtitle: Padding(
                padding: EdgeInsets.only(top: 10.0),
                child: CustomCupertinoTextField(
                  cursorColor: Theme.of(context).primaryColor,
                  onLongPressStart: () {
                    Feedback.forLongPress(context);
                  },
                  onTap: () {
                    HapticFeedback.selectionClick();
                  },
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: inputFormatters,
                  autocorrect: true,
                  controller: controller,
                  scrollPhysics: CustomBouncingScrollPhysics(),
                  style: Theme.of(context).textTheme.bodyText1.apply(
                      color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
                          ? Colors.black
                          : Colors.white,
                      fontSizeDelta: -0.25),
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  minLines: 1,
                  placeholder: placeholder ?? "Enter your text here",
                  padding: EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
                  placeholderStyle: Theme.of(context).textTheme.subtitle1,
                  autofocus: SettingsManager().settings.autoOpenKeyboard,
                  decoration: BoxDecoration(
                    color: Theme.of(context).backgroundColor,
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            Divider(
              color: Theme.of(context).accentColor.withOpacity(0.5),
              thickness: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsSwitch extends StatefulWidget {
  SettingsSwitch({
    Key key,
    this.initialVal,
    this.onChanged,
    this.title,
  }) : super(key: key);
  final bool initialVal;
  final Function(bool) onChanged;
  final String title;

  @override
  _SettingsSwitchState createState() => _SettingsSwitchState();
}

class _SettingsSwitchState extends State<SettingsSwitch> {
  bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialVal;
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        widget.title,
        style: Theme.of(context).textTheme.bodyText1,
      ),
      value: _value,
      activeColor: Theme.of(context).primaryColor,
      activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
      inactiveTrackColor: Theme.of(context).accentColor.withOpacity(0.6),
      inactiveThumbColor: Theme.of(context).accentColor,
      onChanged: (bool val) {
        widget.onChanged(val);

        if (!this.mounted) return;

        setState(() {
          _value = val;
        });
      },
    );
  }
}

class SettingsOptions<T> extends StatefulWidget {
  SettingsOptions({
    Key key,
    this.onChanged,
    this.options,
    this.initial,
    this.textProcessing,
    this.title,
    this.subtitle,
    this.showDivider = true,
  }) : super(key: key);
  final String title;
  final Function(dynamic) onChanged;
  final List<T> options;
  final T initial;
  final String Function(dynamic) textProcessing;
  final bool showDivider;
  final String subtitle;

  @override
  _SettingsOptionsState createState() => _SettingsOptionsState();
}

class _SettingsOptionsState<T> extends State<SettingsOptions<T>> {
  T currentVal;

  @override
  void initState() {
    super.initState();
    currentVal = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                  ),
                  (widget.subtitle != null)
                      ? Container(
                          child: Padding(
                            padding: EdgeInsets.only(top: 3.0),
                            child: Text(
                              widget.subtitle ?? "",
                              style: Theme.of(context).textTheme.subtitle1,
                            ),
                          ),
                        )
                      : Container(),
                ]),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).accentColor,
              ),
              child: Center(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    dropdownColor: Theme.of(context).accentColor,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).textTheme.bodyText1.color,
                    ),
                    value: currentVal,
                    items: widget.options.map<DropdownMenuItem<T>>((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(
                          GetUtils.capitalize(widget.textProcessing(e)),
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                      );
                    }).toList(),
                    onChanged: (T val) {
                      widget.onChanged(val);

                      if (!this.mounted) return;

                      setState(() {
                        currentVal = val;
                      });
                      //
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      (widget.showDivider)
          ? Divider(
              color: Theme.of(context).accentColor.withOpacity(0.5),
              thickness: 1,
            )
          : Container()
    ]);
  }
}

class SettingsSlider extends StatefulWidget {
  SettingsSlider(
      {@required this.startingVal,
      this.update,
      @required this.text,
      this.formatValue,
      @required this.min,
      @required this.max,
      @required this.divisions,
      Key key})
      : super(key: key);

  final double startingVal;
  final Function(double val) update;
  final String text;
  final Function(double value) formatValue;
  final double min;
  final double max;
  final int divisions;

  @override
  _SettingsSliderState createState() => _SettingsSliderState();
}

class _SettingsSliderState extends State<SettingsSlider> {
  double currentVal = 500;

  @override
  void initState() {
    super.initState();
    if (widget.startingVal > 0 && widget.startingVal < 5000) {
      currentVal = widget.startingVal;
    }
  }

  @override
  Widget build(BuildContext context) {
    String value = currentVal.toString();
    if (widget.formatValue != null) {
      value = widget.formatValue(currentVal);
    }

    return Column(
      children: <Widget>[
        ListTile(
          title: Text(
            "${widget.text}: $value",
            style: Theme.of(context).textTheme.bodyText1,
          ),
          subtitle: Slider(
            activeColor: Theme.of(context).primaryColor,
            inactiveColor: Theme.of(context).primaryColor.withOpacity(0.2),
            value: currentVal,
            onChanged: (double value) {
              if (!this.mounted) return;

              setState(() {
                currentVal = value;
                widget.update(currentVal);
              });
            },
            label: value,
            divisions: widget.divisions,
            min: widget.min,
            max: widget.max,
          ),
        ),
        Divider(
          color: Theme.of(context).accentColor.withOpacity(0.5),
          thickness: 1,
        ),
      ],
    );
  }
}
