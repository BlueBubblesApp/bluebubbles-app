import 'dart:ui';

import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PrivateAPIPanelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PrivateAPIPanelController>(() => PrivateAPIPanelController());
  }
}

class PrivateAPIPanelController extends GetxController {
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

  void saveSettings() async {
    await SettingsManager().saveSettings(_settingsCopy);
  }

  @override
  void dispose() {
    saveSettings();
    super.dispose();
  }
}

class PrivateAPIPanel extends GetView<PrivateAPIPanelController> {

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
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.enablePrivateAPI.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.enablePrivateAPI.value,
                    title: "Enable Private API Features",
                  )),
                ],
              ),
            ),
            Obx(() => controller._settingsCopy.enablePrivateAPI.value ? SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.sendTypingIndicators.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.sendTypingIndicators.value,
                    title: "Send Typing Indicators",
                  )),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.privateMarkChatAsRead.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.privateMarkChatAsRead.value,
                    title: "Mark Chats as Read / Send Read Receipts",
                  )),
                  Obx(() => !controller._settingsCopy.privateMarkChatAsRead.value ? SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.privateManualMarkAsRead.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.privateManualMarkAsRead.value,
                    title: "Show Manually Mark Chat as Read Button",
                  ) : Container()),
                ],
              ),
            ) : SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
