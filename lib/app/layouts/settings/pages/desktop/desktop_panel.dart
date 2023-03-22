import 'dart:io';
import 'dart:math';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:reorderables/reorderables.dart';
import 'package:window_manager/window_manager.dart';

class DesktopPanel extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _DesktopPanelState();
}

class _DesktopPanelState extends OptimizedState<DesktopPanel> {
  final RxList<bool> showButtons = RxList<bool>.filled(ReactionTypes.toList().length + 1, false);
  final RxnBool useCustomPath = RxnBool(ss.prefs.getBool("use-custom-path"));
  final RxnString customPath = RxnString(ss.prefs.getString("custom-path"));

  @override
  Widget build(BuildContext context) {
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
                      ss.settings.launchAtStartup.value = val;
                      saveSettings();
                      if (val) {
                        await LaunchAtStartup.enable();
                      } else {
                        await LaunchAtStartup.disable();
                      }
                    },
                    initialVal: ss.settings.launchAtStartup.value,
                    title: "Launch on Startup",
                    subtitle: "Automatically open the desktop app on startup.",
                    backgroundColor: tileColor,
                  )),
                  if (Platform.isLinux)
                    const SettingsDivider(),
                  if (Platform.isLinux)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) async {
                        ss.settings.useCustomTitleBar.value = val;
                        await windowManager.setTitleBarStyle(val ? TitleBarStyle.hidden : TitleBarStyle.normal);
                        saveSettings();
                      },
                      initialVal: ss.settings.useCustomTitleBar.value,
                      title: "Use Custom TitleBar",
                      subtitle:
                          "Enable the custom titlebar. This is necessary on non-GNOME systems, and will not look good on GNOME systems. This is also necessary for 'Close to Tray' and 'Minimize to Tray' to work correctly.",
                      backgroundColor: tileColor,
                    )),
                  Obx(() {
                    if (ss.settings.useCustomTitleBar.value || !Platform.isLinux) {
                      return const SettingsDivider();
                    }
                    return const SizedBox.shrink();
                  }),
                  Obx(() {
                    if (ss.settings.useCustomTitleBar.value || !Platform.isLinux) {
                      return SettingsSwitch(
                        onChanged: (bool val) async {
                          ss.settings.minimizeToTray.value = val;
                          saveSettings();
                        },
                        initialVal: ss.settings.minimizeToTray.value,
                        title: "Minimize to Tray",
                        subtitle:
                            "When enabled, clicking the minimize button will minimize the app to the system tray",
                        backgroundColor: tileColor,
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  Obx(() {
                    if (ss.settings.useCustomTitleBar.value || !Platform.isLinux) {
                      return const SettingsDivider();
                    }
                    return const SizedBox.shrink();
                  }),
                  Obx(() {
                    if (ss.settings.useCustomTitleBar.value || !Platform.isLinux) {
                      return SettingsSwitch(
                        onChanged: (bool val) async {
                          ss.settings.closeToTray.value = val;
                          saveSettings();
                        },
                        initialVal: ss.settings.closeToTray.value,
                        title: "Close to Tray",
                        subtitle: "When enabled, clicking the close button will minimize the app to the system tray",
                        backgroundColor: tileColor,
                      );
                    }
                    return const SizedBox.shrink();
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
              Obx(() => SettingsSection(
                backgroundColor: tileColor,
                children: [
                  SettingsSwitch(
                    initialVal: ss.settings.betterScrolling.value,
                    onChanged: (bool val) async {
                      ss.settings.betterScrolling.value = val;
                      saveSettings();
                    },
                    title: "Improve Mouse Wheel Scrolling",
                    subtitle: "Enabling this setting will break touch scrolling and trackpad scrolling.",
                  ),
                  if (ss.settings.betterScrolling.value)
                    SettingsSlider(
                      leading: const Text("Multiplier"),
                      max: 14.0,
                      min: 4.0,
                      divisions: 20,
                      startingVal: ss.settings.betterScrollingMultiplier.value,
                      update: (double val) {
                        ss.settings.betterScrollingMultiplier.value = val;
                      },
                      onChangeEnd: (double val) {
                        saveSettings();
                      },
                      backgroundColor: tileColor,
                    )
                ],
              )),
              SettingsHeader(
                  headerColor: headerColor,
                  tileColor: tileColor,
                  iosSubtitle: iosSubtitle,
                  materialSubtitle: materialSubtitle,
                  text: "Notifications"),
              SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    const SettingsTile(
                      title: "Actions",
                      subtitle:
                          "Click actions to toggle them. Drag actions to move them. You can select up to 5 actions. Tapback actions require Private API to be enabled.",
                      isThreeLine: true,
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
                                  padding: const EdgeInsets.all(15),
                                  child: Center(
                                    child: ReorderableWrap(
                                      needsLongPressDraggable: false,
                                      spacing: 10,
                                      alignment: WrapAlignment.center,
                                      buildDraggableFeedback: (context, constraints, child) => AnimatedScale(
                                          duration: const Duration(milliseconds: 250), scale: 1.1, child: child),
                                      onReorder: (int oldIndex, int newIndex) {
                                        List<String> selected = ss
                                            .settings
                                            .selectedActionIndices
                                            .map((index) => ss.settings.actionList[index])
                                            .toList();
                                        String? temp = ss.settings.actionList[oldIndex];
                                        // If dragging to the right
                                        for (int i = oldIndex; i <= newIndex - 1; i++) {
                                          ss.settings.actionList[i] =
                                              ss.settings.actionList[i + 1];
                                        }
                                        // If dragging to the left
                                        for (int i = oldIndex; i >= newIndex + 1; i--) {
                                          ss.settings.actionList[i] =
                                              ss.settings.actionList[i - 1];
                                        }
                                        ss.settings.actionList[newIndex] = temp;

                                        List<int> selectedIndices = selected
                                            .map((s) => ss.settings.actionList.indexOf(s))
                                            .toList();
                                        ss.settings.selectedActionIndices.value = selectedIndices;
                                        saveSettings();
                                      },
                                      children: List.generate(
                                        ReactionTypes.toList().length + 1,
                                        (int index) => MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          onEnter: (event) => showButtons[index] = true,
                                          onExit: (event) => showButtons[index] = false,
                                          child: Obx(
                                            () {
                                              bool selected =
                                                  ss.settings.selectedActionIndices.contains(index);

                                              String value = ss.settings.actionList[index];

                                              bool disabled = (!ss.settings.enablePrivateAPI.value &&
                                                  value != "Mark Read");

                                              bool hardDisabled = (!selected &&
                                                  (ss.settings.selectedActionIndices.length == 5));

                                              Color color = selected
                                                  ? context.theme.colorScheme.primary
                                                  : context.theme.colorScheme.properSurface.lightenOrDarken(10);

                                              return MouseRegion(
                                                cursor:
                                                    hardDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
                                                child: GestureDetector(
                                                  behavior: HitTestBehavior.translucent,
                                                  onTap: () {
                                                    if (hardDisabled) return;
                                                    if (!ss
                                                        .settings
                                                        .selectedActionIndices
                                                        .remove(index)) {
                                                      ss.settings.selectedActionIndices.add(index);
                                                    }
                                                    saveSettings();
                                                  },
                                                  child: AnimatedContainer(
                                                    margin: const EdgeInsets.symmetric(vertical: 5),
                                                    height: 56,
                                                    width: 90,
                                                    padding: const EdgeInsets.symmetric(horizontal: 9),
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
                                                    duration: const Duration(milliseconds: 150),
                                                    child: Center(
                                                      child: Material(
                                                        color: Colors.transparent,
                                                        child: Text(
                                                          ReactionTypes.reactionToEmoji[value] ?? "Mark Read",
                                                          style: TextStyle(
                                                              fontSize: 16,
                                                              color: (hardDisabled && value == "Mark Read")
                                                                  ? context.textTheme.titleMedium!.color
                                                                  : null),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ),
                                                    ),
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
                            ns.listener.value;
                            double width = min(ns.width(context) / 2, 400);
                            return Container(
                              width: ns.width(context) > 1500
                                  ? 800
                                  : min(ns.width(context) / 2, 400),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                runAlignment: WrapAlignment.center,
                                children: [
                                  Obx(() {
                                    int markReadIndex = ss.settings.actionList.indexOf("Mark Read");
                                    Iterable<int> actualIndices = ss
                                        .settings
                                        .selectedActionIndices
                                        .where((s) =>
                                            ss.settings.enablePrivateAPI.value || s == markReadIndex);
                                    int numActions = actualIndices.length;
                                    bool showMarkRead =
                                        ss.settings.selectedActionIndices.contains(markReadIndex);
                                    ns.listener.value;
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
                                        color: context.theme.colorScheme.primaryContainer.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: context.theme.colorScheme.primaryContainer),
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
                                              style: context.textTheme.bodyMedium!.copyWith(fontSize: size * 0.036),
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
                                            ss.settings.actionList.length,
                                            (index) => (!actualIndices.contains(index))
                                                ? null
                                                : Obx(
                                                    () {
                                                      context.width;
                                                      int _index = ss
                                                          .settings
                                                          .actionList
                                                          .whereIndexed(
                                                              (index, element) => actualIndices.contains(index))
                                                          .toList()
                                                          .indexOf(ss.settings.actionList[index]);
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
                                                                color:
                                                                    context.theme.colorScheme.outline.withOpacity(0.2)),
                                                            color: context.theme.colorScheme.primary.withOpacity(0.6),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              index == markReadIndex
                                                                  ? ss.settings.actionList[index]
                                                                  : ReactionTypes.reactionToEmoji[
                                                                      ss.settings.actionList[index]]!,
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
                                    int markReadIndex = ss.settings.actionList.indexOf("Mark Read");
                                    Iterable<int> actualIndices = ss
                                        .settings
                                        .selectedActionIndices
                                        .where((s) =>
                                            ss.settings.enablePrivateAPI.value || s == markReadIndex);
                                    int numActions = actualIndices.length;
                                    bool showMarkRead =
                                        ss.settings.selectedActionIndices.contains(markReadIndex);
                                    if (numActions <= (showMarkRead ? 1 : 0)) {
                                      return const SizedBox.shrink();
                                    }
                                    ns.listener.value;
                                    context.width;
                                    double margin = 20;
                                    double size = width - 2 * margin;
                                    return Container(
                                      width: size,
                                      height: size / 3 * (!showMarkRead ? 0.9 : 1.28),
                                      margin: EdgeInsets.symmetric(vertical: margin / 2, horizontal: margin),
                                      decoration: BoxDecoration(
                                        color: context.theme.colorScheme.primaryContainer.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: context.theme.colorScheme.primaryContainer),
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
                                              style: context.textTheme.bodyMedium!.copyWith(fontSize: size * 0.036),
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
                                                      color: context.theme.colorScheme.outline.withOpacity(0.2)),
                                                  color: context.theme.colorScheme.primary.withOpacity(0.6),
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
                  Obx(() => SettingsSwitch(
                    onChanged: (bool val) async {
                      useCustomPath.value = val;
                      if ((!val && ss.prefs.getString("custom-path") != customPath.value) ||
                          ss.prefs.getBool("use-custom-path") == true) {
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
                              backgroundColor: context.theme.colorScheme.properSurface,
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
                                    fs.deleteDB();
                                    socket.forgetConnection();
                                    ss.settings = Settings();
                                    ss.fcmData = FCMData();
                                    await ss.prefs.clear();
                                    await ss.prefs.setString("selected-dark", "OLED Dark");
                                    await ss.prefs.setString("selected-light", "Bright White");
                                    await ss.prefs.setBool("use-custom-path", val);
                                    await windowManager.close();
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
                  )),
                  Obx(() => useCustomPath.value == true
                    ? SettingsTile(
                        title: "Set Custom Path",
                        subtitle:
                            "Custom Path: ${ss.prefs.getBool('use-custom-path') == true ? customPath.value ?? "" : ""}",
                        trailing: TextButton(
                          onPressed: () async {
                            String? path = await FilePicker.platform
                                .getDirectoryPath(dialogTitle: 'Select a Folder', lockParentWindow: true);
                            if (path == null) {
                              showSnackbar("Notice", "You did not select a folder!");
                              return;
                            }
                            if (ss.prefs.getBool("use-custom-path") == true && path == customPath.value) {
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
                                  backgroundColor: context.theme.colorScheme.properSurface,
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
                                        fs.deleteDB();
                                        socket.forgetConnection();
                                        ss.settings = Settings();
                                        ss.fcmData = FCMData();
                                        await ss.prefs.clear();
                                        await ss.prefs.setString("selected-dark", "OLED Dark");
                                        await ss.prefs.setString("selected-light", "Bright White");
                                        await ss.prefs.setBool("use-custom-path", true);
                                        await ss.prefs.setString("custom-path", path);
                                        await windowManager.close();
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: const Text(
                            "Click here to select a folder",
                          ),
                        ),
                      )
                    : const SizedBox.shrink()),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void saveSettings() {
    ss.saveSettings();
  }
}
