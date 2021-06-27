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

/// attaches the controller to the view automatically
class AttachmentPanelBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AttachmentPanelController>(() => AttachmentPanelController());
  }
}

/// controller to manage the view
class AttachmentPanelController extends GetxController {
  Settings _settingsCopy;

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'theme-update') {
        update();
      }
    });
  }

  /// save our settings when disposed
  @override
  void dispose() {
    SettingsManager().saveSettings(_settingsCopy);
    super.dispose();
  }
}

/// getview is just an extension of StatelessWidget, it allows us to use
/// the controller getter without needing a variable in place
class AttachmentPanel extends GetView<AttachmentPanelController> {

  @override
  Widget build(BuildContext context) {
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
                    Get.back();
                  },
                ),
                backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
                title: Text(
                  "Attachment Settings",
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
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.autoDownload.value = val;
                    },
                    initialVal: controller._settingsCopy.autoDownload.value,
                    title: "Auto-download Attachments",
                  )),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.onlyWifiDownload.value = val;
                    },
                    initialVal: controller._settingsCopy.onlyWifiDownload.value,
                    title: "Only Auto-download Attachments on WiFi",
                  )),
                  Obx(() => SettingsSlider(
                      text: "Attachment Chunk Size",
                      currentVal: controller._settingsCopy.chunkSize.value.toDouble(),
                      update: (double val) {
                        controller._settingsCopy.chunkSize.value = val.floor();
                      },
                      formatValue: ((double val) => getSizeString(val)),
                      min: 100,
                      max: 3000,
                      divisions: 29
                  )),
                  Obx(() => SettingsSlider(
                      text: "Attachment Preview Quality",
                      currentVal: controller._settingsCopy.previewCompressionQuality.value.toDouble(),
                      update: (double val) {
                        controller._settingsCopy.previewCompressionQuality.value = val.toInt();
                      },
                      formatValue: ((double val) => val.toInt().toString() + "%"),
                      min: 10,
                      max: 100,
                      divisions: 18
                  )),
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
}
