import 'dart:ui';

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

class AttachmentPanel extends StatefulWidget {
  AttachmentPanel({Key key}) : super(key: key);

  @override
  _AttachmentPanelState createState() => _AttachmentPanelState();
}

class _AttachmentPanelState extends State<AttachmentPanel> {
  Settings _settingsCopy;

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
                brightness: ThemeData.estimateBrightnessForColor(Get.theme.backgroundColor),
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
                  "Attachment Settings",
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
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.autoDownload = val;
                    },
                    initialVal: _settingsCopy.autoDownload,
                    title: "Auto-download Attachments",
                  ),
                  SettingsSwitch(
                    onChanged: (bool val) {
                      _settingsCopy.onlyWifiDownload = val;
                    },
                    initialVal: _settingsCopy.onlyWifiDownload,
                    title: "Only Auto-download Attachments on WiFi",
                  ),
                  SettingsSlider(
                      text: "Attachment Chunk Size",
                      startingVal: _settingsCopy.chunkSize.toDouble(),
                      update: (double val) {
                        _settingsCopy.chunkSize = val.floor();
                      },
                      formatValue: ((double val) => getSizeString(val)),
                      min: 100,
                      max: 3000,
                      divisions: 29),
                  SettingsSlider(
                      text: "Attachment Preview Quality",
                      startingVal: _settingsCopy.previewCompressionQuality.toDouble(),
                      update: (double val) {
                        _settingsCopy.previewCompressionQuality = val.toInt();
                      },
                      formatValue: ((double val) => val.toInt().toString() + "%"),
                      min: 10,
                      max: 100,
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
