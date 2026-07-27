import 'dart:io';
import 'dart:math';

import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/database/models.dart' hide PlatformFile;
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:reorderables/reorderables.dart';
import 'package:window_manager/window_manager.dart';

class DesktopPanel extends StatefulWidget {
  const DesktopPanel({super.key});

  @override
  State<StatefulWidget> createState() => _DesktopPanelState();
}

class _DesktopPanelState extends State<DesktopPanel> with ThemeHelpers {
  final RxList<bool> showButtons = RxList<bool>.filled(ReactionTypes.toList().length + 1, false);
  final RxBool playingNotificationSound = false.obs;
  final Player notificationPlayer = Player();

  @override
  void initState() {
    super.initState();

    notificationPlayer.stream.playing.listen((value) => playingNotificationSound.value = value);
  }

  @override
  Widget build(BuildContext context) {
    final RxInt maxActions = Platform.isWindows
        ? (SettingsSvc.settings.showReplyField.value ? 4 : 5).obs
        : SettingsSvc.settings.actionList.length.obs;

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
                          SettingsSvc.settings.launchAtStartup.value = await SettingsSvc.setupLaunchAtStartup(
                              val, SettingsSvc.settings.launchAtStartupMinimized.value);
                          await SettingsSvc.settings.saveOneAsync('launchAtStartup');
                        },
                        initialVal: SettingsSvc.settings.launchAtStartup.value,
                        title: "Launch on Startup",
                        subtitle: "Automatically open the desktop app on startup.",
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.rocket,
                          materialIcon: Icons.rocket_launch_outlined,
                          containerColor: Colors.blue,
                        ),
                      )),
                  Obx(() => AnimatedSizeAndFade.showHide(
                      show: SettingsSvc.settings.launchAtStartup.value,
                      child: SettingsTile(
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.doc,
                          materialIcon: Icons.description_outlined,
                          containerColor: Colors.green,
                        ),
                        onTap: LaunchAtStartup.revealShortcut,
                        title: "Show Startup Entry",
                        subtitle: SettingsSvc.settings.launchAtStartup.value && LaunchAtStartup.shortcutPath != null
                            ? "Startup entry: ${LaunchAtStartup.shortcutPath}"
                            : "",
                      ))),
                  Obx(() => AnimatedSizeAndFade.showHide(
                        show: SettingsSvc.settings.launchAtStartup.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              color: tileColor,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 15.0),
                                child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                              ),
                            ),
                            SettingsSwitch(
                              onChanged: (bool val) async {
                                SettingsSvc.settings.launchAtStartupMinimized.value = val;
                                SettingsSvc.settings.launchAtStartup.value = await SettingsSvc.setupLaunchAtStartup(
                                    SettingsSvc.settings.launchAtStartup.value, val);
                                await SettingsSvc.settings.saveOneAsync('launchAtStartupMinimized');
                              },
                              initialVal: SettingsSvc.settings.launchAtStartupMinimized.value,
                              title: "Launch on Startup Minimized",
                              subtitle:
                                  "Automatically open the desktop app on startup, but minimized to the system tray",
                              backgroundColor: tileColor,
                              leading: const SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.eye_slash,
                                materialIcon: Icons.hide_image_outlined,
                                containerColor: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (Platform.isLinux)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                      ),
                    ),
                  if (Platform.isLinux)
                    Obx(() {
                      if (iOS) {
                        return const SettingsTile(
                          title: "TitleBar Style",
                          leading: SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.macwindow,
                            materialIcon: Icons.tab_outlined,
                            containerColor: Colors.orange,
                          ),
                          subtitle:
                              "Select the titlebar style. Native uses system window decorations and looks best on GNOME. Custom is necessary on non-GNOME systems and required for 'Minimize to Tray' to work correctly. Hidden removes all titlebar elements.",
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
                  if (Platform.isLinux)
                    Obx(() => SettingsOptions<BBTitleBarStyle>(
                          initial: SettingsSvc.settings.titleBarStyle.value,
                          onChanged: (val) async {
                            if (val == null) return;
                            SettingsSvc.settings.titleBarStyle.value = val;
                            await windowManager.setTitleBarStyle(
                                val == BBTitleBarStyle.native ? TitleBarStyle.normal : TitleBarStyle.hidden);
                            await SettingsSvc.settings.saveOneAsync('titleBarStyle');
                          },
                          options: BBTitleBarStyle.values,
                          textProcessing: (val) => val.toString().split(".").last,
                          title: "TitleBar Style",
                          subtitle:
                              "Select the titlebar style. Native uses system window decorations and looks best on GNOME. Custom is necessary on non-GNOME systems and required for 'Minimize to Tray' to work correctly. Hidden removes all titlebar elements.",
                          secondaryColor: headerColor,
                          leading: const SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.macwindow,
                            materialIcon: Icons.tab_outlined,
                            containerColor: Colors.orange,
                          ),
                        )),
                  Obx(() {
                    if (SettingsSvc.settings.titleBarStyle.value == BBTitleBarStyle.custom || !Platform.isLinux) {
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsSvc.settings.titleBarStyle.value == BBTitleBarStyle.custom || !Platform.isLinux) {
                      return SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsSvc.settings.minimizeToTray.value = val;
                          await SettingsSvc.settings.saveOneAsync('minimizeToTray');
                        },
                        initialVal: SettingsSvc.settings.minimizeToTray.value,
                        title: "Minimize to Tray",
                        subtitle: "When enabled, clicking the minimize button will minimize the app to the system tray",
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.tray_arrow_down,
                          materialIcon: Icons.expand_circle_down_outlined,
                          containerColor: Colors.indigo,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsSvc.settings.titleBarStyle.value == BBTitleBarStyle.custom) {
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 15.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsSvc.settings.closeToTray.value = val;
                          await windowManager.setPreventClose(val);
                          await SettingsSvc.settings.saveOneAsync('closeToTray');
                        },
                        initialVal: SettingsSvc.settings.closeToTray.value,
                        title: "Close to Tray",
                        subtitle: "When enabled, clicking the close button will minimize the app to the system tray",
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.tray_arrow_down_fill,
                          materialIcon: Icons.expand_circle_down,
                          containerColor: Colors.green,
                        ),
                      )),
                ],
              ),
              SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Notifications"),
              SettingsSection(
                backgroundColor: tileColor,
                children: [
                  if (Platform.isWindows)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) async {
                        SettingsSvc.settings.windowsTaskbarBadge.value = val;
                        await SettingsSvc.settings.saveOneAsync('windowsTaskbarBadge');
                        ChatsSvc.unreadCount.refresh();  // Trigger listener
                      },
                      initialVal: SettingsSvc.settings.windowsTaskbarBadge.value,
                      title: "Taskbar Badge",
                      subtitle: "Enable badge on taskbar icon for new messages",
                      backgroundColor: tileColor,
                      leading: const SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.app_badge,
                        materialIcon: Icons.mark_chat_unread_outlined,
                        containerColor: Colors.teal,
                      ),
                    )),
                  Obx(() => SettingsSwitch(
                        onChanged: (bool val) async {
                          SettingsSvc.settings.desktopNotifications.value = val;
                          await SettingsSvc.settings.saveOneAsync('desktopNotifications');
                        },
                        initialVal: SettingsSvc.settings.desktopNotifications.value,
                        title: "Desktop Notifications",
                        subtitle: "Enable desktop notifications for new messages",
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.bell,
                          materialIcon: Icons.notifications_outlined,
                          containerColor: Colors.red,
                        ),
                      )),
                  Obx(() => AnimatedSizeAndFade.showHide(
                        show: SettingsSvc.settings.desktopNotifications.value,
                        child: SettingsTile(
                          leading: const SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.folder,
                            materialIcon: Icons.folder_outlined,
                            containerColor: Colors.purple,
                          ),
                          title:
                              "${SettingsSvc.settings.desktopNotificationSoundPath.value == null ? "Add" : "Change"} Notification Sound",
                          subtitle: SettingsSvc.settings.desktopNotificationSoundPath.value != null
                              ? basename(SettingsSvc.settings.desktopNotificationSoundPath.value!)
                                  .substring("notification-".length)
                              : "Adds a sound to be played with notifications. This is separate from the system notification settings.${Platform.isWindows ? " This will silence the system notification sound." : ""}",
                          onTap: () async {
                            FilePickerResult? result = await FilePicker.pickFiles(type: FileType.audio, withData: true);
                            if (result != null) {
                              PlatformFile platformFile = result.files.first;
                              String path = join(FilesystemSvc.soundsPath, "notification-${platformFile.name}");
                              await File(path).create(recursive: true);
                              await File(path).writeAsBytes(platformFile.bytes!);
                              SettingsSvc.settings.desktopNotificationSoundPath.value = path;
                              await SettingsSvc.settings.saveOneAsync('desktopNotificationSoundPath');
                            }
                          },
                          trailing: SettingsSvc.settings.desktopNotificationSoundPath.value != null
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: playingNotificationSound.value
                                            ? Icon(SettingsSvc.settings.skin.value == Skins.iOS
                                                ? CupertinoIcons.stop
                                                : Icons.stop_outlined)
                                            : Icon(SettingsSvc.settings.skin.value == Skins.iOS
                                                ? CupertinoIcons.play
                                                : Icons.play_arrow_outlined),
                                        onPressed: () async {
                                          final Player _notificationPlayer = notificationPlayer;
                                          if (playingNotificationSound.value) {
                                            await _notificationPlayer.stop();
                                          } else {
                                            await _notificationPlayer.setVolume(
                                                SettingsSvc.settings.desktopNotificationSoundVolume.value.toDouble());
                                            await _notificationPlayer
                                                .open(Media(SettingsSvc.settings.desktopNotificationSoundPath.value!));
                                          }
                                        }),
                                    IconButton(
                                      icon: Icon(SettingsSvc.settings.skin.value == Skins.iOS
                                          ? CupertinoIcons.trash
                                          : Icons.delete_outline),
                                      onPressed: () async {
                                        File file = File(SettingsSvc.settings.desktopNotificationSoundPath.value!);
                                        if (await file.exists()) {
                                          await file.delete();
                                        }
                                        SettingsSvc.settings.desktopNotificationSoundPath.value = null;
                                        await SettingsSvc.settings.saveOneAsync('desktopNotificationSoundPath');
                                      },
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      )),
                  Obx(() => AnimatedSizeAndFade.showHide(
                      show: SettingsSvc.settings.desktopNotifications.value &&
                          SettingsSvc.settings.desktopNotificationSoundPath.value != null,
                      child: const SettingsTile(
                        leading: SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.volume_up,
                          materialIcon: Icons.volume_up_outlined,
                          containerColor: Colors.cyan,
                        ),
                        title: "Notification Sound Volume",
                        subtitle: "Controls the volume of the notification sounds",
                      ))),
                  Obx(() => AnimatedSizeAndFade.showHide(
                        show: SettingsSvc.settings.desktopNotifications.value &&
                            SettingsSvc.settings.desktopNotificationSoundPath.value != null,
                        child: SettingsSlider(
                          startingVal: SettingsSvc.settings.desktopNotificationSoundVolume.value.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          formatValue: (val) => "${val.toInt()}",
                          update: (val) {
                            SettingsSvc.settings.desktopNotificationSoundVolume.value = val.toInt();
                          },
                          onChangeEnd: (val) async {
                            SettingsSvc.settings.desktopNotificationSoundVolume.value = val.toInt();
                            await SettingsSvc.settings.saveOneAsync('desktopNotificationSoundVolume');
                          },
                        ),
                      )),
                  Obx(() => AnimatedSizeAndFade.showHide(
                        show: SettingsSvc.settings.desktopNotifications.value,
                        child: const SettingsDivider(padding: EdgeInsets.only(left: 16.0)),
                      )),
                  Obx(() => AnimatedSizeAndFade.showHide(
                        show: SettingsSvc.settings.desktopNotifications.value,
                        child: SettingsTile(
                          title: "Actions",
                          subtitle:
                              "Click actions to toggle them. Drag actions to move them. ${Platform.isWindows ? "You can select up to 5 actions." : "The number of actions actually visible varies by distribution."} Tapback actions require Private API to be enabled.",
                          isThreeLine: true,
                          leading: const SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.bolt,
                            materialIcon: Icons.bolt_outlined,
                            containerColor: Colors.brown,
                          ),
                        ),
                      )),
                  Obx(() => SettingsSvc.settings.desktopNotifications.value
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Container(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (Platform.isWindows)
                                      SettingsSwitch(
                                        initialVal: SettingsSvc.settings.showReplyField.value,
                                        onChanged: (value) async {
                                          SettingsSvc.settings.showReplyField.value = value;
                                          maxActions.value = value ? 4 : 5;
                                          if (SettingsSvc.settings.selectedActionIndices.length > maxActions.value) {
                                            SettingsSvc.settings.selectedActionIndices.removeLast();
                                          }
                                          await SettingsSvc.settings.saveOneAsync('showReplyField');
                                        },
                                        leading: const SettingsLeadingIcon(
                                          iosIcon: CupertinoIcons.arrowshape_turn_up_left,
                                          materialIcon: Icons.reply_outlined,
                                          containerColor: Colors.orange,
                                        ),
                                        title: "Show Reply Field",
                                        subtitle:
                                            "Show a reply field in the notification. This counts as one of your actions.",
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(15),
                                      child: Center(
                                        child: ReorderableWrap(
                                          needsLongPressDraggable: false,
                                          spacing: 10,
                                          alignment: WrapAlignment.center,
                                          buildDraggableFeedback: (context, constraints, child) => AnimatedScale(
                                              duration: const Duration(milliseconds: 250), scale: 1.1, child: child),
                                          onReorder: (int oldIndex, int newIndex) async {
                                            List<String> selected = SettingsSvc.settings.selectedActionIndices
                                                .map((index) => SettingsSvc.settings.actionList[index])
                                                .toList();
                                            String? temp = SettingsSvc.settings.actionList[oldIndex];
                                            // If dragging to the right
                                            for (int i = oldIndex; i <= newIndex - 1; i++) {
                                              SettingsSvc.settings.actionList[i] =
                                                  SettingsSvc.settings.actionList[i + 1];
                                            }
                                            // If dragging to the left
                                            for (int i = oldIndex; i >= newIndex + 1; i--) {
                                              SettingsSvc.settings.actionList[i] =
                                                  SettingsSvc.settings.actionList[i - 1];
                                            }
                                            SettingsSvc.settings.actionList[newIndex] = temp;

                                            List<int> selectedIndices = selected
                                                .map((s) => SettingsSvc.settings.actionList.indexOf(s))
                                                .toList();
                                            selectedIndices.sort();
                                            SettingsSvc.settings.selectedActionIndices.value = selectedIndices;
                                            await SettingsSvc.settings.saveOneAsync('selectedActionIndices');
                                          },
                                          children: List.generate(
                                            ReactionTypes.toList().length + 1,
                                            (int index) => MouseRegion(
                                              cursor: MouseCursor.defer,
                                              onEnter: (event) => showButtons[index] = true,
                                              onExit: (event) => showButtons[index] = false,
                                              child: Obx(
                                                () {
                                                  bool selected =
                                                      SettingsSvc.settings.selectedActionIndices.contains(index);

                                                  String value = SettingsSvc.settings.actionList[index];

                                                  bool disabled = (!SettingsSvc.settings.enablePrivateAPI.value &&
                                                      value != "Mark Read");

                                                  bool hardDisabled = (!selected &&
                                                      (SettingsSvc.settings.selectedActionIndices.length ==
                                                          maxActions.value));

                                                  Color color = selected
                                                      ? context.theme.colorScheme.primary
                                                      : context.theme.colorScheme.surfaceContainerHighest
                                                          .lightenOrDarken(10);

                                                  return MouseRegion(
                                                    cursor: hardDisabled ? SystemMouseCursors.basic : MouseCursor.defer,
                                                    child: GestureDetector(
                                                      behavior: HitTestBehavior.translucent,
                                                      onTap: () async {
                                                        if (hardDisabled) return;
                                                        if (!SettingsSvc.settings.selectedActionIndices.remove(index)) {
                                                          SettingsSvc.settings.selectedActionIndices.add(index);
                                                          SettingsSvc.settings.selectedActionIndices.sort();
                                                        }

                                                        await SettingsSvc.settings
                                                            .saveOneAsync('selectedActionIndices');
                                                      },
                                                      child: AnimatedContainer(
                                                        margin: const EdgeInsets.symmetric(vertical: 5),
                                                        height: 56,
                                                        width: 90,
                                                        padding: const EdgeInsets.symmetric(horizontal: 9),
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(
                                                              color: color.withValues(alpha: selected ? 1 : 0.5),
                                                              width: selected ? 1.5 : 1),
                                                          color: color.withValues(
                                                              alpha: disabled
                                                                  ? 0.2
                                                                  : selected
                                                                      ? 0.8
                                                                      : 0.7),
                                                        ),
                                                        foregroundDecoration: BoxDecoration(
                                                          color: color.withValues(
                                                              alpha: hardDisabled || disabled ? 0.7 : 0),
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
                            if (Platform.isWindows)
                              Obx(
                                () {
                                  context.width;
                                  NavigationSvc.listener.value;
                                  double width = min(NavigationSvc.width(context) / 2, 400);
                                  return SizedBox(
                                      width: NavigationSvc.width(context) > 1500
                                          ? 800
                                          : min(NavigationSvc.width(context) / 2, 400),
                                      child: Obx(() {
                                        int markReadIndex = SettingsSvc.settings.actionList.indexOf("Mark Read");
                                        Iterable<int> actualIndices = SettingsSvc.settings.selectedActionIndices.where(
                                            (s) => SettingsSvc.settings.enablePrivateAPI.value || s == markReadIndex);
                                        int numActions = actualIndices.length;
                                        bool showMarkRead =
                                            SettingsSvc.settings.selectedActionIndices.contains(markReadIndex);
                                        bool showReplyField = SettingsSvc.settings.showReplyField.value;
                                        NavigationSvc.listener.value;
                                        double margin = 20;
                                        double size = width - 2 * margin;
                                        return Container(
                                          height: size /
                                              3 *
                                              (numActions == 0
                                                  ? showReplyField
                                                      ? 1.3
                                                      : 0.9
                                                  : showMarkRead && numActions > 3
                                                      ? showReplyField
                                                          ? 1.83
                                                          : 1.41
                                                      : showReplyField
                                                          ? 1.72
                                                          : 1.28),
                                          width: size,
                                          margin: EdgeInsets.symmetric(vertical: margin / 2, horizontal: margin),
                                          decoration: BoxDecoration(
                                            color: context.theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
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
                                                    style:
                                                        context.textTheme.bodyMedium!.copyWith(fontSize: size * 0.0305),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: size * 0.12,
                                                left: size * 0.04,
                                                child: ContactAvatarWidget(
                                                  borderThickness: 0,
                                                  editable: false,
                                                  handle: Handle(address: "John Doe"),
                                                  fontSize: size * 0.135 * 0.93 * 0.5,
                                                  size: size * 0.135,
                                                ),
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
                                                  style: context.textTheme.bodyMedium!.copyWith(
                                                      fontSize: size * 0.036,
                                                      color: context.theme.colorScheme.onPrimaryContainer),
                                                ),
                                              ),
                                              if (showReplyField)
                                                Positioned(
                                                  // bottom: size * 0.04,
                                                  top: size * 0.3,
                                                  left: size * 0.04,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: context.theme.colorScheme.primary.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(5),
                                                      border: Border(
                                                          bottom: BorderSide(
                                                              color: context.theme.colorScheme.primary
                                                                  .withValues(alpha: 0.8))),
                                                    ),
                                                    padding: EdgeInsets.symmetric(
                                                        horizontal: size * 0.02, vertical: size * 0.016),
                                                    height: size * 0.09,
                                                    width: size * 0.92 * 0.82,
                                                    child: Text("Type a reply...",
                                                        style: context.textTheme.bodyMedium!.copyWith(
                                                            fontSize: size * 0.038,
                                                            color: context.theme.colorScheme.onPrimaryContainer
                                                                .withValues(alpha: 0.8))),
                                                  ),
                                                ),
                                              if (showReplyField)
                                                Positioned(
                                                  top: size * 0.3,
                                                  right: size * 0.04,
                                                  child: Container(
                                                      decoration: BoxDecoration(
                                                        color: context.theme.colorScheme.primary.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(5),
                                                      ),
                                                      padding: EdgeInsets.symmetric(
                                                          horizontal: size * 0.02, vertical: size * 0.016),
                                                      height: size * 0.09,
                                                      width: size * 0.92 * 0.15,
                                                      child: Center(
                                                          child: Text("Reply",
                                                              style: context.textTheme.bodyMedium!.copyWith(
                                                                  fontSize: size * 0.038,
                                                                  color: context.theme.colorScheme.onPrimaryContainer
                                                                      .withValues(alpha: 0.3))))),
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
                                                SettingsSvc.settings.actionList.length,
                                                (index) => (!actualIndices.contains(index))
                                                    ? null
                                                    : Obx(
                                                        () {
                                                          context.width;
                                                          int _index = SettingsSvc.settings.actionList
                                                              .whereIndexed(
                                                                  (index, element) => actualIndices.contains(index))
                                                              .toList()
                                                              .indexOf(SettingsSvc.settings.actionList[index]);
                                                          return Positioned(
                                                            bottom: size * 0.04,
                                                            left: size * 0.04 +
                                                                (_index *
                                                                        (size * 0.92 -
                                                                            ((numActions - 1) * size * 0.02)) /
                                                                        numActions -
                                                                    0.5) +
                                                                (size * _index * 0.02) -
                                                                ((_index == 0 || _index == numActions - 1)
                                                                    ? 0.5
                                                                    : 0.25),
                                                            child: Container(
                                                              height: size *
                                                                  (!showMarkRead || numActions < 4 ? 0.09 : 0.13),
                                                              width: (size * 0.92 - ((numActions - 1) * size * 0.02)) /
                                                                      numActions -
                                                                  0.5,
                                                              padding: EdgeInsets.symmetric(
                                                                  vertical: size * 0.01, horizontal: size * 0.02),
                                                              decoration: BoxDecoration(
                                                                borderRadius: BorderRadius.circular(5),
                                                                border: Border.all(
                                                                    color: context.theme.colorScheme.outline
                                                                        .withValues(alpha: 0.2)),
                                                                color: context.theme.colorScheme.primary
                                                                    .withValues(alpha: 0.12),
                                                              ),
                                                              child: Center(
                                                                child: Text(
                                                                  index == markReadIndex
                                                                      ? SettingsSvc.settings.actionList[index]
                                                                      : ReactionTypes.reactionToEmoji[
                                                                          SettingsSvc.settings.actionList[index]]!,
                                                                  style: context.textTheme.bodyMedium!
                                                                      .copyWith(fontSize: size * 0.037),
                                                                  textAlign: TextAlign.center,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                              ).nonNulls,
                                            ],
                                          ),
                                        );
                                      }));
                                },
                              ),
                          ],
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

  @override
  void dispose() {
    notificationPlayer.dispose();

    super.dispose();
  }
}
