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

class ConvoSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ConvoSettingsController>(() => ConvoSettingsController());
  }
}

class ConvoSettingsController extends GetxController {
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

class ConvoSettings extends GetView<ConvoSettingsController> {

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
                    Navigator.of(context).pop();
                  },
                ),
                backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
                title: Text(
                  "Conversation Settings",
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
                  Container(padding: EdgeInsets.only(top: 5.0)),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.showDeliveryTimestamps.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.showDeliveryTimestamps.value,
                    title: "Show Delivery Timestamps",
                  )),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.autoOpenKeyboard.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.autoOpenKeyboard.value,
                    title: "Auto-open Keyboard",
                  )),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.swipeToCloseKeyboard.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.swipeToCloseKeyboard.value,
                    title: "Swipe TextField to Close Keyboard",
                  )),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.swipeToOpenKeyboard.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.swipeToOpenKeyboard.value,
                    title: "Swipe TextField to Open Keyboard",
                  )),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.hideKeyboardOnScroll.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.hideKeyboardOnScroll.value,
                    title: "Hide Keyboard on Scroll",
                  )),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.openKeyboardOnSTB.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.openKeyboardOnSTB.value,
                    title: "Open Keyboard on Scrolling to Bottom Tap",
                  )),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.recipientAsPlaceholder.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.recipientAsPlaceholder.value,
                    title: "Show Recipient (or Group Name) as Placeholder",
                  )),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.doubleTapForDetails.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.doubleTapForDetails.value,
                    title: "Double-Tap Message for Details",
                  )),
                  // SettingsSwitch(
                  //   onChanged: (bool val) {
                  //     _settingsCopy.sendTypingIndicators = val;
                  //   },
                  //   initialVal: _settingsCopy.sendTypingIndicators,
                  //   title: "Send typing indicators (BlueBubblesHelper ONLY)",
                  // ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.smartReply.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.smartReply.value,
                    title: "Smart Replies",
                  )),
                  if (controller._settingsCopy.smartReply.value)
                    Obx(() => SettingsSlider(
                        text: "Smart Reply Sample Size",
                        currentVal: controller._settingsCopy.smartReplySampleSize.value.toDouble(),
                        update: (double val) {
                          controller._settingsCopy.smartReplySampleSize.value = val.toInt();
                          controller.saveSettings();
                        },
                        formatValue: ((double val) => val.toStringAsFixed(2)),
                        min: 1,
                        max: 10,
                        divisions: 9
                    )),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.sendWithReturn.value = val;
                      controller.saveSettings();
                    },
                    initialVal: controller._settingsCopy.sendWithReturn.value,
                    title: "Send Message with Return Key",
                  )),
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
}
