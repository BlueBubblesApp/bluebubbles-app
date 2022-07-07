import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ConversationPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final iosSubtitle =
    context.theme.textTheme.labelLarge?.copyWith(color: ThemeManager().inDarkMode(context) ? context.theme.colorScheme.onBackground : context.theme.colorScheme.properOnSurface, fontWeight: FontWeight.w300);
    final materialSubtitle = context.theme
        .textTheme
        .labelLarge
        ?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold);
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.background : context.theme.colorScheme.properSurface;
    Color tileColor = ThemeManager().inDarkMode(context)
        ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background;
    
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material && ThemeManager().inDarkMode(context)) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }

    return SettingsScaffold(
      title: "Conversations",
      initialHeader: "Customization",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      tileColor: tileColor,
      headerColor: headerColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.showDeliveryTimestamps.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.showDeliveryTimestamps.value,
                    title: "Show Delivery Timestamps",
                    backgroundColor: tileColor,
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.recipientAsPlaceholder.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.recipientAsPlaceholder.value,
                    title: "Show Chat Name as Placeholder",
                    subtitle: "Changes the default hint text in the message box to display the recipient name",
                    backgroundColor: tileColor,
                    isThreeLine: true,
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15.0),
                      child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                    ),
                  ),
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) {
                      SettingsManager().settings.alwaysShowAvatars.value = val;
                      saveSettings();
                    },
                    initialVal: SettingsManager().settings.alwaysShowAvatars.value,
                    title: "Show Avatars in DM Chats",
                    subtitle: "Shows contact avatars in direct messages rather than just in group messages",
                    backgroundColor: tileColor,
                    isThreeLine: true,
                  )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.smartReply.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.smartReply.value,
                      title: "Show Smart Replies",
                      subtitle: "Shows smart reply suggestions above the message text field",
                      backgroundColor: tileColor,
                      isThreeLine: true,
                    )),
                ],
              ),
              SettingsHeader(
                  headerColor: headerColor,
                  tileColor: tileColor,
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Gestures"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.autoOpenKeyboard.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.autoOpenKeyboard.value,
                      title: "Auto-open Keyboard",
                      subtitle: "Automatically open the keyboard when entering a chat",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.swipeToCloseKeyboard.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.swipeToCloseKeyboard.value,
                      title: "Swipe Message Box to Close Keyboard",
                      subtitle: "Swipe down on the message box to hide the keyboard",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.swipeToOpenKeyboard.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.swipeToOpenKeyboard.value,
                      title: "Swipe Message Box to Open Keyboard",
                      subtitle: "Swipe up on the message box to show the keyboard",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.hideKeyboardOnScroll.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.hideKeyboardOnScroll.value,
                      title: "Hide Keyboard When Scrolling",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.openKeyboardOnSTB.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.openKeyboardOnSTB.value,
                      title: "Open Keyboard After Tapping Scroll To Bottom",
                      backgroundColor: tileColor,
                    )),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  Container(
                    color: tileColor,
                    child: Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.doubleTapForDetails.value = val;
                        if (val && SettingsManager().settings.enableQuickTapback.value) {
                          SettingsManager().settings.enableQuickTapback.value = false;
                        }
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.doubleTapForDetails.value,
                      title: "Double-${kIsWeb || kIsDesktop ? "Click" : "Tap"} Message for Details",
                      subtitle: "Opens the message details popup when double ${kIsWeb || kIsDesktop ? "click" : "tapp"}ing a message",
                      backgroundColor: tileColor,
                      isThreeLine: true,
                    )),
                  ),
                  if (!kIsDesktop && !kIsWeb)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (!kIsDesktop && !kIsWeb)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) {
                        SettingsManager().settings.sendWithReturn.value = val;
                        saveSettings();
                      },
                      initialVal: SettingsManager().settings.sendWithReturn.value,
                      title: "Send Message with Enter",
                      backgroundColor: tileColor,
                    )),
                ],
              ),
            ],
          ),
        ),
      ]
    );
  }

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }
}
