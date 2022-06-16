import 'dart:io';
import 'dart:math';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DesktopPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final RxnBool useCustomPath = RxnBool(prefs.getBool("use-custom-path"));
    final RxnString customPath = RxnString(prefs.getString("custom-path"));
    final iosSubtitle =
    context.theme.textTheme.labelLarge?.copyWith(color: ThemeManager().inDarkMode(context) ? context.theme.colorScheme.onBackground : context.theme.colorScheme.onSurface, fontWeight: FontWeight.w300);
    final materialSubtitle = context.theme
        .textTheme
        .labelLarge
        ?.copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold);
    // Samsung theme should always use the background color as the "header" color
    Color headerColor = ThemeManager().inDarkMode(context)
        || SettingsManager().settings.skin.value == Skins.Samsung
        ? context.theme.colorScheme.background : context.theme.colorScheme.surface;
    Color tileColor = ThemeManager().inDarkMode(context)
        || SettingsManager().settings.skin.value == Skins.Samsung
        ? context.theme.colorScheme.surface : context.theme.colorScheme.background;
    // make sure the tile color is at least different from the header color on Samsung and iOS
    if (tileColor == headerColor) {
      tileColor = context.theme.colorScheme.surfaceVariant;
    }
    // reverse material color mapping to be more accurate
    if (SettingsManager().settings.skin.value == Skins.Material) {
      final temp = headerColor;
      headerColor = tileColor;
      tileColor = temp;
    }

    RxList showButtons = RxList.generate(ReactionTypes.toList().length + 1, (index) => false);

    return SettingsScaffold(
      title: "Desktop Settings",
      initialHeader: "Window Behavior",
      iosSubtitle: iosSubtitle,
      materialSubtitle: materialSubtitle,
      headerColor: headerColor,
      tileColor: tileColor,
      bodySlivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsManager().settings.launchAtStartup.value = val;
                          saveSettings();
                          if (val) {
                            await LaunchAtStartup.enable();
                          } else {
                            await LaunchAtStartup.disable();
                          }
                        },
                        initialVal: SettingsManager().settings.launchAtStartup.value,
                        title: "Launch on Startup",
                        subtitle: "Automatically open the desktop app on startup.",
                        backgroundColor: tileColor,
                      )),
                  if (Platform.isLinux)
                    Obx(
                      () => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsManager().settings.useCustomTitleBar.value = val;
                          saveSettings();
                        },
                        initialVal: SettingsManager().settings.useCustomTitleBar.value,
                        title: "Use Custom TitleBar",
                        subtitle:
                            "Enable the custom titlebar. This is necessary on non-GNOME systems, and will not look good on GNOME systems. This is also necessary for 'Close to Tray' and 'Minimize to Tray' to work correctly.",
                        backgroundColor: tileColor,
                      ),
                    ),
                  Obx(() {
                    if (SettingsManager().settings.useCustomTitleBar.value || !Platform.isLinux) {
                      return Obx(
                        () => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsManager().settings.minimizeToTray.value = val;
                            saveSettings();
                          },
                          initialVal: SettingsManager().settings.minimizeToTray.value,
                          title: "Minimize to Tray",
                          subtitle:
                              "When enabled, clicking the minimize button will minimize the app to the system tray",
                          backgroundColor: tileColor,
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.useCustomTitleBar.value || !Platform.isLinux) {
                      return Obx(
                        () => SettingsSwitch(
                          onChanged: (bool val) async {
                            SettingsManager().settings.closeToTray.value = val;
                            saveSettings();
                          },
                          initialVal: SettingsManager().settings.closeToTray.value,
                          title: "Close to Tray",
                          subtitle: "When enabled, clicking the close button will minimize the app to the system tray",
                          backgroundColor: tileColor,
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  }),
                ],
              ),
              SettingsHeader(
                headerColor: headerColor,
                tileColor: tileColor,
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                text: "Scrolling",
              ),
              Obx(
                () => SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    SettingsSwitch(
                      initialVal: SettingsManager().settings.betterScrolling.value,
                      onChanged: (bool val) async {
                        SettingsManager().settings.betterScrolling.value = val;
                        saveSettings();
                      },
                      title: "Improve Mouse Wheel Scrolling",
                      subtitle: "Enabling this setting will break touch scrolling and degrade trackpad scrolling.",
                    ),
                    if (SettingsManager().settings.betterScrolling.value)
                      SettingsSlider(
                        leading: Text("Multiplier"),
                        max: 14.0,
                        min: 4.0,
                        divisions: 20,
                        startingVal: SettingsManager().settings.betterScrollingMultiplier.value,
                        text: SettingsManager().settings.betterScrollingMultiplier.value.toString(),
                        update: (double val) {
                          SettingsManager().settings.betterScrollingMultiplier.value = val;
                        },
                        onChangeEnd: (double val) {
                          saveSettings();
                        },
                        backgroundColor: tileColor,
                      )
                  ],
                ),
              ),
              if (Platform.isWindows)
                SettingsHeader(
                    headerColor: headerColor,
                    tileColor: tileColor,
                    iosSubtitle: iosSubtitle,
                    materialSubtitle: materialSubtitle,
                    text: "Notifications"),
              if (Platform.isWindows)
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    SettingsTile(
                      title: "Actions",
                      subtitle:
                          "Click actions to toggle them. Click the arrows to move them. You can select up to 5 actions. Tapback actions require Private API to be enabled.",
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Padding(
                                  padding: EdgeInsets.all(15),
                                  child: Center(
                                    child: Wrap(
                                      spacing: 10,
                                      alignment: WrapAlignment.center,
                                      children: List.generate(
                                        ReactionTypes.toList().length + 1,
                                        (int index) => MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          onEnter: (event) => showButtons[index] = true,
                                          onExit: (event) => showButtons[index] = false,
                                          child: Obx(
                                            () {
                                              bool selected =
                                                  SettingsManager().settings.selectedActionIndices.contains(index);

                                              String value = SettingsManager().settings.actionList[index];

                                              bool disabled = (!SettingsManager().settings.enablePrivateAPI.value &&
                                                  value != "Mark Read");

                                              bool hardDisabled = (!selected &&
                                                  (SettingsManager().settings.selectedActionIndices.length == 5));

                                              Color color = selected
                                                  ? context.theme.primaryColor
                                                  : context.theme.colorScheme.secondary;

                                              RxBool hoverRight = false.obs;
                                              RxBool hoverLeft = false.obs;

                                              return MouseRegion(
                                                cursor:
                                                    hardDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.translucent,
                                                  onTap: () {
                                                    if (hardDisabled) return;
                                                    if (!SettingsManager()
                                                        .settings
                                                        .selectedActionIndices
                                                        .remove(index)) {
                                                      SettingsManager().settings.selectedActionIndices.add(index);
                                                    }
                                                  },
                                                  child: Stack(
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      AnimatedContainer(
                                                        margin: EdgeInsets.symmetric(vertical: 5),
                                                        height: 56,
                                                        width: 90,
                                                        padding: EdgeInsets.symmetric(horizontal: 9),
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                              color: color.withOpacity(selected ? 1 : 0.5),
                                                              width: selected ? 1.5 : 1),
                                                          color: color.withOpacity(disabled
                                                              ? 0.2
                                                              : selected
                                                                  ? 0.8
                                                                  : 0.7),
                                                        ),
                                                        foregroundDecoration: BoxDecoration(
                                                          color: color.withOpacity(hardDisabled || disabled ? 0.7 : 0),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        curve: Curves.linear,
                                                        duration: Duration(milliseconds: 150),
                                                        child: Center(
                                                          child: Material(
                                                            color: Colors.transparent,
                                                            child: Text(
                                                              ReactionTypes.reactionToEmoji[value] ?? "Mark Read",
                                                              style: TextStyle(
                                                                  fontSize: 16,
                                                                  color: (hardDisabled && value == "Mark Read")
                                                                      ? context.textTheme.labelLarge!.color
                                                                      : null),
                                                              textAlign: TextAlign.center,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        left: -1,
                                                        top: 4,
                                                        height: 60,
                                                        width: 24,
                                                        child: AnimatedScale(
                                                          duration: Duration(milliseconds: 100),
                                                          scale: index != 0 && showButtons[index] ? 1 : 0,
                                                          curve: Curves.bounceIn,
                                                          child: MouseRegion(
                                                            cursor: SystemMouseCursors.click,
                                                            onEnter: (event) {
                                                              if (hoverLeft.value != true) {
                                                                hoverLeft.value = true;
                                                              }
                                                            },
                                                            onExit: (event) {
                                                              if (hoverLeft.value != false) {
                                                                hoverLeft.value = false;
                                                              }
                                                            },
                                                            child: GestureDetector(
                                                              onTap: () {
                                                                bool currentSelected = SettingsManager()
                                                                    .settings
                                                                    .selectedActionIndices
                                                                    .contains(index);
                                                                bool previousSelected = SettingsManager()
                                                                    .settings
                                                                    .selectedActionIndices
                                                                    .contains(index - 1);
                                                                String temp =
                                                                    SettingsManager().settings.actionList[index];
                                                                SettingsManager().settings.actionList[index] =
                                                                    SettingsManager().settings.actionList[index - 1];
                                                                SettingsManager().settings.actionList[index - 1] = temp;
                                                                if (!previousSelected && currentSelected) {
                                                                  SettingsManager()
                                                                      .settings
                                                                      .selectedActionIndices
                                                                      .remove(index);
                                                                  SettingsManager()
                                                                      .settings
                                                                      .selectedActionIndices
                                                                      .add(index - 1);
                                                                }
                                                                if (previousSelected && !currentSelected) {
                                                                  SettingsManager()
                                                                      .settings
                                                                      .selectedActionIndices
                                                                      .add(index);
                                                                  SettingsManager()
                                                                      .settings
                                                                      .selectedActionIndices
                                                                      .remove(index - 1);
                                                                }
                                                              },
                                                              child: Obx(
                                                                () => AnimatedContainer(
                                                                  duration: Duration(milliseconds: 100),
                                                                  decoration: BoxDecoration(
                                                                    borderRadius: BorderRadius.only(
                                                                        topLeft: Radius.circular(8),
                                                                        bottomLeft: Radius.circular(8)),
                                                                  ),
                                                                  width: 24,
                                                                  height: 60,
                                                                  child: AnimatedScale(
                                                                    scale: hoverLeft.value ? 1.5 : 1,
                                                                    curve: Curves.bounceInOut,
                                                                    duration: Duration(milliseconds: 100),
                                                                    child: Icon(Icons.arrow_left,
                                                                        color: context.theme.textTheme.bodyMedium!.color,
                                                                        size: 24),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        right: -1,
                                                        top: 4,
                                                        height: 60,
                                                        width: 24,
                                                        child: AnimatedScale(
                                                          duration: Duration(milliseconds: 100),
                                                          scale: index != ReactionTypes.toList().length &&
                                                                  showButtons[index]
                                                              ? 1
                                                              : 0,
                                                          curve: Curves.bounceIn,
                                                          child: MouseRegion(
                                                            cursor: SystemMouseCursors.click,
                                                            onEnter: (event) {
                                                              if (hoverRight.value != true) {
                                                                hoverRight.value = true;
                                                              }
                                                            },
                                                            onExit: (event) {
                                                              if (hoverRight.value != false) {
                                                                hoverRight.value = false;
                                                              }
                                                            },
                                                            child: GestureDetector(
                                                              behavior: HitTestBehavior.opaque,
                                                              onTap: () {
                                                                bool currentSelected = SettingsManager()
                                                                    .settings
                                                                    .selectedActionIndices
                                                                    .contains(index);
                                                                bool nextSelected = SettingsManager()
                                                                    .settings
                                                                    .selectedActionIndices
                                                                    .contains(index + 1);
                                                                String temp =
                                                                    SettingsManager().settings.actionList[index];
                                                                SettingsManager().settings.actionList[index] =
                                                                    SettingsManager().settings.actionList[index + 1];
                                                                SettingsManager().settings.actionList[index + 1] = temp;
                                                                if (!nextSelected && currentSelected) {
                                                                  SettingsManager()
                                                                      .settings
                                                                      .selectedActionIndices
                                                                      .remove(index);
                                                                  SettingsManager()
                                                                      .settings
                                                                      .selectedActionIndices
                                                                      .add(index + 1);
                                                                }
                                                                if (nextSelected && !currentSelected) {
                                                                  SettingsManager()
                                                                      .settings
                                                                      .selectedActionIndices
                                                                      .add(index);
                                                                  SettingsManager()
                                                                      .settings
                                                                      .selectedActionIndices
                                                                      .remove(index + 1);
                                                                }
                                                              },
                                                              child: Obx(
                                                                () => AnimatedContainer(
                                                                  duration: Duration(milliseconds: 100),
                                                                  decoration: BoxDecoration(
                                                                    borderRadius: BorderRadius.only(
                                                                        topRight: Radius.circular(8),
                                                                        bottomRight: Radius.circular(8)),
                                                                    color: Colors.transparent,
                                                                  ),
                                                                  width: 24,
                                                                  height: 60,
                                                                  child: AnimatedScale(
                                                                    scale: hoverRight.value ? 1.5 : 1,
                                                                    curve: Curves.bounceInOut,
                                                                    duration: Duration(milliseconds: 100),
                                                                    child: Icon(Icons.arrow_right,
                                                                        color: context.theme.textTheme.bodyMedium!.color,
                                                                        size: 24),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Obx(
                          () {
                            context.width;
                            CustomNavigator.listener.value;
                            double width = min(CustomNavigator.width(context) / 2, 400);
                            return Container(
                              width: CustomNavigator.width(context) > 1500
                                  ? 800
                                  : min(CustomNavigator.width(context) / 2, 400),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                runAlignment: WrapAlignment.center,
                                children: [
                                  Obx(() {
                                    int markReadIndex = SettingsManager().settings.actionList.indexOf("Mark Read");
                                    Iterable<int> actualIndices = SettingsManager()
                                        .settings
                                        .selectedActionIndices
                                        .where((s) =>
                                            SettingsManager().settings.enablePrivateAPI.value || s == markReadIndex);
                                    int numActions = actualIndices.length;
                                    bool showMarkRead =
                                        SettingsManager().settings.selectedActionIndices.contains(markReadIndex);
                                    CustomNavigator.listener.value;
                                    context.width;
                                    double margin = 20;
                                    double size = width - 2 * margin;
                                    return Container(
                                      height: size /
                                          3 *
                                          (numActions == 0
                                              ? 0.9
                                              : showMarkRead && numActions > 3
                                                  ? 1.41
                                                  : 1.28),
                                      width: size,
                                      margin: EdgeInsets.symmetric(vertical: margin / 2, horizontal: margin),
                                      decoration: BoxDecoration(
                                        color: context.theme.colorScheme.secondary.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: context.theme.colorScheme.secondary),
                                      ),
                                      child: Stack(
                                        children: <Widget>[
                                          Positioned(
                                            top: size * 0.035,
                                            left: size * 0.04,
                                            child: Image.asset("assets/icon/icon.ico",
                                                width: size * 0.043, height: size * 0.043),
                                          ),
                                          Positioned(
                                            top: size * 0.035,
                                            left: size * 0.106,
                                            child: Center(
                                              child: Text(
                                                "BlueBubbles",
                                                style: context.textTheme.bodyMedium!.copyWith(fontSize: size * 0.0305),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.11,
                                            left: size * 0.034,
                                            child: ContactAvatarWidget(
                                                editable: false,
                                                handle: Handle(address: "John Doe"),
                                                fontSize: size * 0.144 * 0.93 * 0.5,
                                                size: size * 0.144),
                                          ),
                                          Positioned(
                                            top: size * 0.132,
                                            left: size * 0.216,
                                            child: Text(
                                              "John Doe",
                                              style: context.textTheme.bodyMedium!.copyWith(fontSize: size * 0.036),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.182,
                                            left: size * 0.216,
                                            child: Text(
                                              "${(numActions > (showMarkRead ? 1 : 0)) ? "Message" : "All"} notifications will look like this.",
                                              style: context.textTheme.labelLarge!.copyWith(fontSize: size * 0.036),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.035,
                                            right: size * 0.15,
                                            child: Center(
                                              child: Icon(Icons.more_horiz,
                                                  size: size * 0.04, color: context.textTheme.labelLarge!.color),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.035,
                                            right: size * 0.05,
                                            child: Center(
                                              child: Icon(Icons.close_rounded,
                                                  size: size * 0.04, color: context.textTheme.labelLarge!.color),
                                            ),
                                          ),
                                          ...List.generate(
                                            SettingsManager().settings.actionList.length,
                                            (index) => (!actualIndices.contains(index))
                                                ? null
                                                : Obx(
                                                    () {
                                                      context.width;
                                                      int _index = SettingsManager()
                                                          .settings
                                                          .actionList
                                                          .whereIndexed(
                                                              (index, element) => actualIndices.contains(index))
                                                          .toList()
                                                          .indexOf(SettingsManager().settings.actionList[index]);
                                                      return Positioned(
                                                        bottom: size * 0.04,
                                                        left: size * 0.04 +
                                                            (_index *
                                                                    (size * 0.92 - ((numActions - 1) * size * 0.02)) /
                                                                    numActions -
                                                                0.5) +
                                                            (size * _index * 0.02) -
                                                            ((_index == 0 || _index == numActions - 1) ? 0.5 : 0.25),
                                                        child: Container(
                                                          height:
                                                              size * (!showMarkRead || numActions < 4 ? 0.09 : 0.13),
                                                          width: (size * 0.92 - ((numActions - 1) * size * 0.02)) /
                                                                  numActions -
                                                              0.5,
                                                          padding: EdgeInsets.symmetric(
                                                              vertical: size * 0.01, horizontal: size * 0.02),
                                                          decoration: BoxDecoration(
                                                            borderRadius: BorderRadius.circular(5),
                                                            border: Border.all(
                                                                color: context.textTheme.bodyMedium!.color!
                                                                    .withOpacity(0.1)),
                                                            color: context.theme.colorScheme.secondary.withOpacity(0.6),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              index == markReadIndex
                                                                  ? SettingsManager().settings.actionList[index]
                                                                  : ReactionTypes.reactionToEmoji[
                                                                      SettingsManager().settings.actionList[index]]!,
                                                              style: context.textTheme.bodyMedium!
                                                                  .copyWith(fontSize: size * 0.037),
                                                              textAlign: TextAlign.center,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                          ).whereNotNull(),
                                        ],
                                      ),
                                    );
                                  }),
                                  Obx(() {
                                    int markReadIndex = SettingsManager().settings.actionList.indexOf("Mark Read");
                                    Iterable<int> actualIndices = SettingsManager()
                                        .settings
                                        .selectedActionIndices
                                        .where((s) =>
                                            SettingsManager().settings.enablePrivateAPI.value || s == markReadIndex);
                                    int numActions = actualIndices.length;
                                    bool showMarkRead =
                                        SettingsManager().settings.selectedActionIndices.contains(markReadIndex);
                                    if (numActions <= (showMarkRead ? 1 : 0)) {
                                      return SizedBox.shrink();
                                    }
                                    CustomNavigator.listener.value;
                                    context.width;
                                    double margin = 20;
                                    double size = width - 2 * margin;
                                    return Container(
                                      width: size,
                                      height: size / 3 * (!showMarkRead ? 0.9 : 1.28),
                                      margin: EdgeInsets.symmetric(vertical: margin / 2, horizontal: margin),
                                      decoration: BoxDecoration(
                                        color: context.theme.colorScheme.secondary.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: context.theme.colorScheme.secondary),
                                      ),
                                      child: Stack(
                                        children: <Widget>[
                                          Positioned(
                                            top: size * 0.035,
                                            left: size * 0.04,
                                            child: Image.asset("assets/icon/icon.ico",
                                                width: size * 0.043, height: size * 0.043),
                                          ),
                                          Positioned(
                                            top: size * 0.035,
                                            left: size * 0.106,
                                            child: Center(
                                              child: Text(
                                                "BlueBubbles",
                                                style: context.textTheme.bodyMedium!.copyWith(fontSize: size * 0.0305),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.11,
                                            left: size * 0.034,
                                            child: ContactAvatarWidget(
                                                editable: false,
                                                handle: Handle(address: "John Doe"),
                                                fontSize: size * 0.144 * 0.93 * 0.5,
                                                size: size * 0.144),
                                          ),
                                          Positioned(
                                            top: size * 0.132,
                                            left: size * 0.216,
                                            child: Text(
                                              "John Doe",
                                              style: context.textTheme.bodyMedium!.copyWith(fontSize: size * 0.036),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.182,
                                            left: size * 0.216,
                                            child: Text(
                                              "Reaction notifications will look like this.",
                                              style: context.textTheme.labelLarge!.copyWith(fontSize: size * 0.036),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.035,
                                            right: size * 0.15,
                                            child: Center(
                                              child: Icon(Icons.more_horiz,
                                                  size: size * 0.04, color: context.textTheme.labelLarge!.color),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.035,
                                            right: size * 0.05,
                                            child: Center(
                                              child: Icon(Icons.close_rounded,
                                                  size: size * 0.04, color: context.textTheme.labelLarge!.color),
                                            ),
                                          ),
                                          if (showMarkRead)
                                            Positioned(
                                              bottom: size * 0.04,
                                              left: size * 0.04 + 0.5,
                                              child: Container(
                                                height: size * 0.09,
                                                width: size * 0.92 - 0.5,
                                                padding: EdgeInsets.symmetric(
                                                    vertical: size * 0.01, horizontal: size * 0.02),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(5),
                                                  border: Border.all(
                                                      color: context.textTheme.bodyMedium!.color!.withOpacity(0.1)),
                                                  color: context.theme.colorScheme.secondary.withOpacity(0.6),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    "Mark Read",
                                                    style:
                                                        context.textTheme.bodyMedium!.copyWith(fontSize: size * 0.037),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            )
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              SettingsHeader(
                  headerColor: headerColor,
                  tileColor: tileColor,
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Advanced"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  Obx(
                    () => SettingsSwitch(
                      onChanged: (bool val) async {
                        useCustomPath.value = val;
                        if ((!val && prefs.getString("custom-path") != customPath.value) ||
                            prefs.getBool("use-custom-path") == true) {
                          await showDialog(
                            barrierDismissible: false,
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(
                                  "Are you sure?",
                                  style: context.theme.textTheme.titleLarge,
                                ),
                                content: Text(
                                    "All of your data and settings will be deleted, and you will have to set the app up again from scratch.", style: context.theme.textTheme.bodyLarge),
                                backgroundColor: context.theme.colorScheme.surface,
                                actions: <Widget>[
                                  TextButton(
                                    child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () {
                                      useCustomPath.value = true;
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: Text("Yes", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () async {
                                      prefs.setBool("use-custom-path", val);
                                      await DBProvider.deleteDB();
                                      await SettingsManager().resetConnection();
                                      SettingsManager().settings.finishedSetup.value = false;
                                      SettingsManager().settings = Settings();
                                      SettingsManager().settings.save();
                                      SettingsManager().fcmData = null;
                                      FCMData.deleteFcmData();
                                      appWindow.close();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      title: 'Use Custom Database Path',
                      subtitle: 'You will have to set the app up again from scratch',
                      initialVal: useCustomPath.value ?? false,
                    ),
                  ),
                  Obx(
                    () => useCustomPath.value == true
                        ? SettingsTile(
                            title: "Set Custom Path",
                            subtitle:
                                "Custom Path: ${prefs.getBool('use-custom-path') == true ? customPath.value ?? "" : ""}",
                            trailing: TextButton(
                              onPressed: () async {
                                String? path = await FilePicker.platform
                                    .getDirectoryPath(dialogTitle: 'Select a Folder', lockParentWindow: true);
                                if (path == null) {
                                  showSnackbar("Notice", "You did not select a folder!");
                                  return;
                                }
                                if (prefs.getBool("use-custom-path") == true && path == customPath.value) {
                                  return;
                                }
                                await showDialog(
                                  barrierDismissible: false,
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text(
                                        "Are you sure?",
                                        style: context.theme.textTheme.titleLarge,
                                      ),
                                      content: Text(
                                          "The database will now be stored at $path\n\nAll of your data and settings will be deleted, and you will have to set the app up again from scratch.", style: context.theme.textTheme.bodyLarge,),
                                      backgroundColor: context.theme.colorScheme.surface,
                                      actions: <Widget>[
                                        TextButton(
                                          child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: Text("Yes", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                          onPressed: () async {
                                            customPath.value = path;
                                            await DBProvider.deleteDB();
                                            await SettingsManager().resetConnection();
                                            SettingsManager().settings.finishedSetup.value = false;
                                            SettingsManager().settings = Settings();
                                            SettingsManager().settings.save();
                                            SettingsManager().fcmData = null;
                                            FCMData.deleteFcmData();
                                            prefs.setBool("use-custom-path", true);
                                            prefs.setString("custom-path", path);
                                            appWindow.close();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: Text(
                                "Click here to select a folder",
                              ),
                            ),
                          )
                        : SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void saveSettings() {
    SettingsManager().saveSettings(SettingsManager().settings);
  }
}
