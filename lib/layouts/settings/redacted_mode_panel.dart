import 'dart:ui';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RedactedModePanelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RedactedModePanelController>(() => RedactedModePanelController());
  }
}

class RedactedModePanelController extends GetxController {
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

  void saveSettings() {
    SettingsManager().saveSettings(_settingsCopy);
  }

  @override
  void dispose() {
    saveSettings();
    super.dispose();
  }

}

class RedactedModePanel extends GetView<RedactedModePanelController> {

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
                  "Redacted Mode Settings",
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
                      title: "What is Redacted Mode?",
                      subTitle:
                          ("Redacted Mode hides your personal information such as contact names, message content, and more. This is useful when taking screenshots to send to developers.")),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.redactedMode.value = val;

                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.redactedMode.value,
                    title: "Enable Redacted Mode",
                  )),
                ],
              ),
            ),
            Obx(() => SliverList(
              delegate: SliverChildListDelegate(
                  controller._settingsCopy.redactedMode.value ? <Widget>[
                    SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.hideMessageContent.value = val;
                        controller.saveSettings();
                      },
                      initialVal: controller._settingsCopy.hideMessageContent.value,
                      title: "Hide Message Content",
                    ),
                    Divider(),
                    SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.hideReactions.value = val;
                        controller.saveSettings();
                      },
                      initialVal: controller._settingsCopy.hideReactions.value,
                      title: "Hide Reactions",
                    ),
                    SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.hideAttachments.value = val;
                        controller.saveSettings();
                      },
                      initialVal: controller._settingsCopy.hideAttachments.value,
                      title: "Hide Attachments",
                    ),
                    SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.hideAttachmentTypes.value = val;
                        controller.saveSettings();
                      },
                      initialVal: controller._settingsCopy.hideAttachmentTypes.value,
                      title: "Hide Attachment Types",
                    ),
                    Divider(),
                    SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.hideContactPhotos.value = val;
                        controller.saveSettings();
                      },
                      initialVal: controller._settingsCopy.hideContactPhotos.value,
                      title: "Hide Contact Photos",
                    ),
                    SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.hideContactInfo.value = val;
                        controller.saveSettings();
                      },
                      initialVal: controller._settingsCopy.hideContactInfo.value,
                      title: "Hide Contact Info",
                    ),
                    SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.removeLetterAvatars.value = val;
                        controller.saveSettings();
                      },
                      initialVal: controller._settingsCopy.removeLetterAvatars.value,
                      title: "Remove Letter Avatars",
                    ),
                    Divider(),
                    SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.generateFakeContactNames.value = val;
                        controller.saveSettings();
                      },
                      initialVal: controller._settingsCopy.generateFakeContactNames.value,
                      title: "Generate Fake Contact Names",
                    ),
                    SettingsSwitch(
                      onChanged: (bool val) {
                        controller._settingsCopy.generateFakeMessageContent.value = val;
                        controller.saveSettings();
                      },
                      initialVal: controller._settingsCopy.generateFakeMessageContent.value,
                      title: "Generate Fake Message Content",
                    ),
                  ] : <Widget>[]
              ),
            ))
          ],
        ),
      ),
    );
  }
}
