import 'dart:async';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

class CustomAvatarPanel extends StatefulWidget {
  CustomAvatarPanel({Key key}) : super(key: key);

  @override
  _CustomAvatarPanelState createState() => _CustomAvatarPanelState();
}

class _CustomAvatarPanelState extends State<CustomAvatarPanel> {
  Settings _settingsCopy;
  List<DisplayMode> modes;
  DisplayMode currentMode;
  Brightness brightness;
  Color previousBackgroundColor;
  bool gotBrightness = false;
  bool isFetching = false;
  List<Widget> handleWidgets = [];

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

    getCustomHandles();
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

  Future<void> getCustomHandles({force: false}) async {
    // If we are already fetching or have results,
    if (!false && (isFetching || !isNullOrEmpty(this.handleWidgets))) return;
    List<Handle> handles = await Handle.find();
    if (isNullOrEmpty(handles)) return;

    // Filter handles down by ones with colors
    handles = handles.where((element) => element.color != null).toList();

    List<Widget> items = [];
    for (var item in handles) {
      items.add(SettingsTile(
        title:
            ContactManager().getCachedContactSync(item.address)?.displayName ?? await formatPhoneNumber(item.address),
        subTitle: "Tap avatar to change color",
        trailing: ContactAvatarWidget(handle: item),
      ));
    }

    if (!isNullOrEmpty(items) && this.mounted) {
      setState(() {
        this.handleWidgets = items;
      });
    }
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
                  icon: Icon(Icons.arrow_back_ios, color: Get.theme.primaryColor),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                backgroundColor: Get.theme.accentColor.withOpacity(0.5),
                title: Text(
                  "Custom Avatar Colors",
                  style: Get.theme.textTheme.headline1,
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
                  if (this.handleWidgets.length == 0)
                    Container(
                        padding: EdgeInsets.all(30),
                        child: Text(
                          "No avatars have been customized! To get started, tap an avatar.",
                          style: Get.theme.textTheme.subtitle1,
                          textAlign: TextAlign.center,
                        )),
                  for (Widget handleWidget in this.handleWidgets ?? []) handleWidget
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
