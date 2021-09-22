import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivateAPIPanelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PrivateAPIPanelController>(() => PrivateAPIPanelController());
  }
}

class PrivateAPIPanelController extends GetxController {
  late Settings _settingsCopy;
  final RxnInt macOSVersionNumber = RxnInt();
  final RxnString macOSVersion = RxnString();

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
    SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
      macOSVersionNumber.value = int.tryParse(res['data']['os_version'].toString().split(".")[0]);
      macOSVersion.value = res['data']['os_version'];
      if ((macOSVersionNumber.value ?? 10) > 10) _settingsCopy.enablePrivateAPI.value = false;
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
    final iosSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if ((Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value == Skins.Material) && (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return SettingsScaffold(
      title: "Private API Features",
      initialHeader: "Private API",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        Obx(() => SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              SettingsSection(
                backgroundColor: tileColor,
                children: [
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
                            ],
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                        ),
                      )
                  ),
                  SettingsTile(
                    backgroundColor: tileColor,
                    title: "Set up Private API Features",
                    subtitle: "View instructions on how to set up these features",
                    onTap: () async {
                      await launch("https://github.com/BlueBubblesApp/BlueBubbles-Server/wiki/Using-Private-API-Features");
                    },
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.checkmark_shield,
                      materialIcon: Icons.privacy_tip,
                    ),
                  ),
                  ((controller.macOSVersionNumber.value ?? 10) < 11) ?
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ) : Container(),
                  (controller.macOSVersionNumber.value ?? 10) < 11 ? SettingsSwitch(
                    onChanged: (bool val) {
                      controller._settingsCopy.enablePrivateAPI.value = val;
                      saveSettings();
                    },
                    initialVal: controller._settingsCopy.enablePrivateAPI.value,
                    title: "Enable Private API Features",
                    backgroundColor: tileColor,
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
                              TextSpan(text: "Current: ${controller.macOSVersion.value ?? "Unknown"}"),
                              TextSpan(text: "\n\n"),
                              TextSpan(text: "Required: 10.15.7 and under"),
                            ],
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                        ),
                      )
                  ),
                ],
              ),
              if (SettingsManager().settings.enablePrivateAPI.value && (controller.macOSVersionNumber.value ?? 10) < 11)
                ...[
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Private API Settings"
                  ),
                  SettingsSection(
                    backgroundColor: tileColor,
                    children: [
                      SettingsSwitch(
                        onChanged: (bool val) {
                          controller._settingsCopy.privateSendTypingIndicators.value = val;
                          saveSettings();
                        },
                        initialVal:controller._settingsCopy.privateSendTypingIndicators.value,
                        title: "Send Typing Indicators",
                        subtitle: "Sends typing indicators to other iMessage users",
                        backgroundColor: tileColor,
                      ),
                      SettingsSwitch(
                        onChanged: (bool val) {
                          controller._settingsCopy.privateMarkChatAsRead.value = val;
                          saveSettings();
                        },
                        initialVal:controller._settingsCopy.privateMarkChatAsRead.value,
                        title: "Mark Chats as Read / Send Read Receipts",
                        subtitle: "Marks chats read in the iMessage app on your server and sends read receipts to other iMessage users",
                        backgroundColor: tileColor,
                      ),
                      if (!controller._settingsCopy.privateMarkChatAsRead.value)
                        SettingsSwitch(
                          onChanged: (bool val) {
                            controller._settingsCopy.privateManualMarkAsRead.value = val;
                            saveSettings();
                          },
                          initialVal:controller._settingsCopy.privateManualMarkAsRead.value,
                          title: "Show Manually Mark Chat as Read Button",
                          backgroundColor: tileColor,
                        ),
                    ]
                  )
                ],
            ],
          ),
        )),
      ]
    );
  }

  void saveSettings() async {
    await SettingsManager().saveSettings(controller._settingsCopy);
  }
}
