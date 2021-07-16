import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/settings/chat_list_panel.dart';
import 'package:bluebubbles/layouts/settings/conversation_panel.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/about_panel.dart';
import 'package:bluebubbles/layouts/settings/attachment_panel.dart';
import 'package:bluebubbles/layouts/settings/private_api_panel.dart';
import 'package:bluebubbles/layouts/settings/redacted_mode_panel.dart';
import 'package:bluebubbles/layouts/settings/server_management_panel.dart';
import 'package:bluebubbles/layouts/settings/theme_panel.dart';
import 'package:bluebubbles/layouts/settings/ux_panel.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoTextField.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


List disconnectedStates = [SocketState.DISCONNECTED, SocketState.ERROR, SocketState.FAILED];

class SettingsPanel extends StatefulWidget {
  SettingsPanel({Key? key}) : super(key: key);

  @override
  _SettingsPanelState createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late Settings _settingsCopy;
  bool needToReconnect = false;
  int? lastRestart;

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

    SettingsManager().stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget nextIcon = Obx(() => Icon(
      SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.chevron_right : Icons.arrow_forward,
      color: Colors.grey,
    ));

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
                  "Settings",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: Obx(() => CustomScrollView(
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
                        child: Text("Server Management".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )
                  ),
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  StreamBuilder(
                      stream: SocketManager().connectionStateStream,
                      builder: (context, AsyncSnapshot<SocketState> snapshot) {
                        late SocketState connectionStatus;
                        if (snapshot.hasData) {
                          connectionStatus = snapshot.data!;
                        } else {
                          connectionStatus = SocketManager().state;
                        }
                        String? subtitle;

                        switch (connectionStatus) {
                          case SocketState.CONNECTED:
                            subtitle = "Connected";
                            break;
                          case SocketState.DISCONNECTED:
                            subtitle = "Disconnected";
                            break;
                          case SocketState.ERROR:
                            subtitle = "Error";
                            break;
                          case SocketState.CONNECTING:
                            subtitle = "Connecting...";
                            break;
                          case SocketState.FAILED:
                            subtitle = "Failed to connect";
                            break;
                          default:
                            subtitle = "Error";
                            break;
                        }

                        return SettingsTile(
                          backgroundColor: tileColor,
                          title: "Connection & Server",
                          subTitle: subtitle,
                          onTap: () async {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) => ServerManagementPanel(),
                              ),
                            );
                          },
                          onLongPress: () {
                            Clipboard.setData(new ClipboardData(text: _settingsCopy.serverAddress));
                            showSnackbar('Copied', "Address copied to clipboard");
                          },
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: SettingsManager().settings.skin.value == Skins.iOS ?
                                  getIndicatorColor(connectionStatus) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                alignment: Alignment.center,
                                child: Stack(
                                    children: [
                                      Icon(SettingsManager().settings.skin.value == Skins.iOS
                                          ? CupertinoIcons.antenna_radiowaves_left_right : Icons.router,
                                          color: SettingsManager().settings.skin.value == Skins.iOS ?
                                          Colors.white : Colors.grey,
                                          size: SettingsManager().settings.skin.value == Skins.iOS ? 23 : 30,
                                      ),
                                      if (SettingsManager().settings.skin.value != Skins.iOS)
                                        Positioned.fill(
                                          child: Align(
                                              alignment: Alignment.bottomRight,
                                              child: getIndicatorIcon(connectionStatus, size: 15, showAlpha: false)
                                          ),
                                        ),
                                    ]
                                ),
                              ),
                            ],
                          ),
                          showDivider: false,
                          trailing: nextIcon,
                        );
                      }),
                  SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Appearance"
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "Theme Settings",
                    subTitle: SettingsManager().settings.skin.value.toString().split(".").last
                        + "   |   " + AdaptiveTheme.of(context).mode.toString().split(".").last.capitalizeFirst! + " Mode",
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ThemePanel(),
                        ),
                      );
                    },
                    showDivider: false,
                    trailing: nextIcon,
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.paintbrush,
                      materialIcon: Icons.palette,
                    ),
                  ),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Application Settings"
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "Media Settings",
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => AttachmentPanel(),
                        ),
                      );
                    },
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.paperclip,
                      materialIcon: Icons.attachment,
                    ),
                    trailing: nextIcon,
                    showDivider: false,
                  ),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "Chat List Settings",
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ChatListPanel(),
                        ),
                      );
                    },
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.square_list,
                      materialIcon: Icons.list,
                    ),
                    showDivider: false,
                    trailing: nextIcon,
                  ),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "Conversation Settings",
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => ConversationPanel(),
                        ),
                      );
                    },
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.chat_bubble,
                      materialIcon: Icons.sms,
                    ),
                    showDivider: false,
                    trailing: nextIcon,
                  ),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "User Experience Settings",
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => UXPanel(),
                        ),
                      );
                    },
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.person_alt,
                      materialIcon: Icons.manage_accounts,
                    ),
                    showDivider: false,
                    trailing: nextIcon,
                  ),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Advanced"
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "Private API Features",
                    subTitle: "Private API ${SettingsManager().settings.enablePrivateAPI.value ? "Enabled" : "Disabled"}",
                    trailing: nextIcon,
                    onTap: () async {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => PrivateAPIPanel(),
                        ),
                      );
                    },
                    showDivider: false,
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.exclamationmark_shield,
                      materialIcon: Icons.gpp_maybe,
                      containerColor: getIndicatorColor(SettingsManager().settings.enablePrivateAPI.value ? SocketState.CONNECTED : SocketState.CONNECTING),
                    ),
                  ),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "Redacted Mode",
                    subTitle: "Redacted Mode ${SettingsManager().settings.redactedMode.value ? "Enabled" : "Disabled"}",
                    trailing: nextIcon,
                    onTap: () async {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => RedactedModePanel(),
                        ),
                      );
                    },
                    showDivider: false,
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.wand_stars,
                      materialIcon: Icons.auto_fix_high,
                      containerColor: getIndicatorColor(SettingsManager().settings.redactedMode.value ? SocketState.CONNECTED : SocketState.CONNECTING),
                    ),
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
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "About"
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "About & Links",
                    subTitle: "Donate, Rate, Changelog, & More",
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => AboutPanel(),
                        ),
                      );
                    },
                    showDivider: false,
                    trailing: nextIcon,
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.info_circle,
                      materialIcon: Icons.info,
                    ),
                  ),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Reset"
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
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
                              TextButton(
                                child: Text("Yes"),
                                onPressed: () async {
                                  await DBProvider.deleteDB();
                                  await SettingsManager().resetConnection();

                                  SocketManager().finishedSetup.sink.add(false);
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                },
                              ),
                              TextButton(
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
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.floppy_disk,
                      materialIcon: Icons.storage,
                    ),
                    title: "Reset",
                    subTitle: "Resets the app to default settings",
                    showDivider: false,
                  ),
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
        )),
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
  const SettingsTile(
      {Key? key,
      this.onTap,
      this.onLongPress,
      this.title,
      this.trailing,
      this.leading,
      this.subTitle,
      this.showDivider = true,
      this.backgroundColor,
      this.isThreeLine = false,
      })
      : super(key: key);

  final Function? onTap;
  final Function? onLongPress;
  final String? subTitle;
  final String? title;
  final Widget? trailing;
  final Widget? leading;
  final bool showDivider;
  final Color? backgroundColor;
  final bool isThreeLine;

  @override
  Widget build(BuildContext context) {
    //todo remove Column and Container once settings is fully done
    return Container(
      color: backgroundColor,
      child: Column(
        children: <Widget>[
          ListTile(
            onLongPress: this.onLongPress as void Function()?,
            tileColor: backgroundColor,
            onTap: this.onTap as void Function()?,
            leading: leading,
            title: Text(
              this.title!,
              style: Theme.of(context).textTheme.bodyText1,
            ),
            trailing: this.trailing,
            subtitle: subTitle != null
                ? Text(
                    subTitle!,
                    style: Theme.of(context).textTheme.subtitle1,
                  )
                : null,
            isThreeLine: isThreeLine,
          ),
          if (showDivider)
            Divider(
              color: Theme.of(context).accentColor.withOpacity(0.5),
              thickness: 1,
            ),
        ],
      ),
    );
  }
}

class SettingsTextField extends StatelessWidget {
  const SettingsTextField(
      {Key? key,
      this.onTap,
      required this.title,
      this.trailing,
      required this.controller,
      this.placeholder,
      this.maxLines = 14,
      this.keyboardType = TextInputType.multiline,
      this.inputFormatters = const []})
      : super(key: key);

  final TextEditingController controller;
  final Function? onTap;
  final String title;
  final String? placeholder;
  final Widget? trailing;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).backgroundColor,
      child: InkWell(
        onTap: this.onTap as void Function()?,
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
                  style: Theme.of(context).textTheme.bodyText1!.apply(
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
    Key? key,
    required this.initialVal,
    this.onChanged,
    required this.title,
    this.backgroundColor,
    this.subtitle,
  }) : super(key: key);
  final bool initialVal;
  final Function(bool)? onChanged;
  final String title;
  final Color? backgroundColor;
  final String? subtitle;

  @override
  _SettingsSwitchState createState() => _SettingsSwitchState();
}

class _SettingsSwitchState extends State<SettingsSwitch> {
  bool? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialVal;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: SwitchListTile(
        tileColor: widget.backgroundColor,
        title: Text(
          widget.title,
          style: Theme.of(context).textTheme.bodyText1,
        ),
        subtitle: widget.subtitle != null ? Text(
          widget.subtitle!,
          style: Theme.of(context).textTheme.subtitle1,
        ) : null,
        value: _value!,
        activeColor: Theme.of(context).primaryColor,
        activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
        inactiveTrackColor: widget.backgroundColor == Theme.of(context).accentColor
            ? Theme.of(context).backgroundColor.withOpacity(0.6) : Theme.of(context).accentColor.withOpacity(0.6),
        inactiveThumbColor: widget.backgroundColor == Theme.of(context).accentColor
            ? Theme.of(context).backgroundColor : Theme.of(context).accentColor,
        onChanged: (bool val) {
          widget.onChanged!(val);

          if (!this.mounted) return;

          setState(() {
            _value = val;
          });
        },
      ),
    );
  }
}

class SettingsOptions<T extends Object> extends StatefulWidget {
  SettingsOptions({
    Key? key,
    required this.onChanged,
    required this.options,
    this.cupertinoCustomWidgets,
    required this.initial,
    this.textProcessing,
    required this.title,
    this.subtitle,
    this.showDivider = true,
    this.capitalize = true,
    this.backgroundColor,
    this.secondaryColor,
  }) : super(key: key);
  final String title;
  final Function(dynamic) onChanged;
  final List<T> options;
  final Iterable<Widget>? cupertinoCustomWidgets;
  final T initial;
  final String Function(dynamic)? textProcessing;
  final bool showDivider;
  final String? subtitle;
  final bool capitalize;
  final Color? backgroundColor;
  final Color? secondaryColor;

  @override
  _SettingsOptionsState createState() => _SettingsOptionsState<T>();
}

class _SettingsOptionsState<T extends Object> extends State<SettingsOptions<T>> {
  late T currentVal;

  @override
  void initState() {
    super.initState();
    currentVal = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    if (SettingsManager().settings.skin.value == Skins.iOS) {
      final texts = widget.options.map((e) => Text(e.toString()));
      final map = Map<T, Widget>.fromIterables(widget.options, widget.cupertinoCustomWidgets ?? texts);
      return Container(
        color: widget.backgroundColor,
        height: 50,
        child: CupertinoSlidingSegmentedControl<T>(
          children: map,
          groupValue: currentVal,
          thumbColor: widget.secondaryColor != null && widget.secondaryColor == widget.backgroundColor
              ? widget.secondaryColor!.lightenOrDarken(20) : widget.secondaryColor ?? Colors.white,
          backgroundColor: widget.backgroundColor ?? CupertinoColors.tertiarySystemFill,
          onValueChanged: (T? val) {
            widget.onChanged(val);

            if (!this.mounted && val != null) return;

            setState(() {
              currentVal = val!;
            });
          },
        ),
      );
    }
    return Container(
      color: widget.backgroundColor,
      child: Column(children: [
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
                        color: Theme.of(context).textTheme.bodyText1!.color,
                      ),
                      value: currentVal,
                      items: widget.options.map<DropdownMenuItem<T>>((e) {
                        return DropdownMenuItem(
                          value: e,
                          child: Text(
                            widget.capitalize ? widget.textProcessing!(e).capitalize! : widget.textProcessing!(e),
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                        );
                      }).toList(),
                      onChanged: (T? val) {
                        widget.onChanged(val);

                        if (!this.mounted || val == null) return;

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
      ]),
    );
  }
}

class SettingsSlider extends StatefulWidget {
  SettingsSlider(
      {required this.startingVal,
      this.update,
      required this.text,
      this.formatValue,
      required this.min,
      required this.max,
      required this.divisions,
      this.showDivider = false,
      this.leading,
      this.backgroundColor,
      Key? key})
      : super(key: key);

  final double startingVal;
  final Function(double val)? update;
  final String text;
  final Function(double value)? formatValue;
  final double min;
  final double max;
  final int divisions;
  final bool showDivider;
  final Widget? leading;
  final Color? backgroundColor;

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
      value = widget.formatValue!(currentVal);
    }

    return Container(
      color: widget.backgroundColor,
      child: Column(
        children: <Widget>[
          ListTile(
            tileColor: widget.backgroundColor,
            leading: widget.leading,
            trailing: Text(value),
            title: SettingsManager().settings.skin.value == Skins.iOS ? CupertinoSlider(
              activeColor: Theme.of(context).primaryColor,
              //inactiveColor: Theme.of(context).primaryColor.withOpacity(0.2),
              value: currentVal,
              onChanged: (double value) {
                if (!this.mounted) return;

                setState(() {
                  currentVal = value;
                  widget.update!(currentVal);
                });
              },
              //label: value,
              divisions: widget.divisions,
              min: widget.min,
              max: widget.max,
            ) : Slider(
              activeColor: Theme.of(context).primaryColor,
              inactiveColor: Theme.of(context).primaryColor.withOpacity(0.2),
              value: currentVal,
              onChanged: (double value) {
                if (!this.mounted) return;

                setState(() {
                  currentVal = value;
                  widget.update!(currentVal);
                });
              },
              label: value,
              divisions: widget.divisions,
              min: widget.min,
              max: widget.max,
            ),
          ),
          if (widget.showDivider)
            Divider(
              color: Theme.of(context).accentColor.withOpacity(0.5),
              thickness: 1,
            ),
        ],
      ),
    );
  }
}

class SettingsHeader extends StatelessWidget {
  final Color headerColor;
  final Color tileColor;
  final TextStyle? iosSubtitle;
  final TextStyle? materialSubtitle;
  final String text;

  SettingsHeader({
    required this.headerColor,
    required this.tileColor,
    required this.iosSubtitle,
    required this.materialSubtitle,
    required this.text
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
        Container(
            height: SettingsManager().settings.skin.value == Skins.iOS ? 60 : 40,
            alignment: Alignment.bottomLeft,
            decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
              color: headerColor,
              border: Border.symmetric(
                  horizontal: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
              ),
            ) : BoxDecoration(
              color: tileColor,
              border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 15),
              child: Text(text.psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
            )
        ),
        Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
      ]
    );
  }
}

class SettingsLeadingIcon extends StatelessWidget {
  final IconData iosIcon;
  final IconData materialIcon;
  final Color? containerColor;

  SettingsLeadingIcon({
    required this.iosIcon,
    required this.materialIcon,
    this.containerColor,
  });

  @override
  Widget build(BuildContext context) {
   return Column(
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
       Container(
         width: 32,
         height: 32,
         decoration: BoxDecoration(
           color: SettingsManager().settings.skin.value == Skins.iOS ?
            containerColor ?? Colors.grey : Colors.transparent,
           borderRadius: BorderRadius.circular(5),
         ),
         alignment: Alignment.center,
         child: Icon(SettingsManager().settings.skin.value == Skins.iOS
             ? iosIcon : materialIcon,
             color: SettingsManager().settings.skin.value == Skins.iOS ?
             Colors.white : Colors.grey,
             size: SettingsManager().settings.skin.value == Skins.iOS ? 23 : 30
         ),
       ),
     ],
   );
  }

}

class SettingsDivider extends StatelessWidget {
  final double thickness;
  final Color? color;

  SettingsDivider({
    this.thickness = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (SettingsManager().settings.skin.value != Skins.Material) {
      return Divider(
        color: color ?? Theme.of(context).accentColor.withOpacity(0.5),
        thickness: 1,
      );
    } else {
      return Container();
    }
  }
}
