import 'dart:io';
import 'dart:math';

import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/settings/pages/desktop/widgets/add_notification_action.dart';
import 'package:bluebubbles/app/layouts/settings/pages/desktop/widgets/grayed_out.dart';
import 'package:bluebubbles/app/layouts/settings/pages/desktop/widgets/notification_action_button.dart';
import 'package:bluebubbles/app/layouts/settings/pages/desktop/widgets/toast_preview_theme.dart';
import 'package:bluebubbles/database/models.dart' hide PlatformFile;
import 'package:bluebubbles/services/services.dart';
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

class _DesktopPanelState extends State<DesktopPanel> with ThemeHelpers, WindowListener {
  final RxBool playingNotificationSound = false.obs;

  /// Read again when the window regains focus, so the preview picks up Personalization changes made in Windows
  /// Settings. Rx only notifies when the value differs, so an unchanged theme doesn't rebuild the preview.
  late final Rx<ToastPreviewTheme>? _toastTheme = Platform.isWindows ? ToastPreviewTheme.read().obs : null;
  final Player notificationPlayer = Player();

  @override
  void initState() {
    super.initState();

    notificationPlayer.stream.playing.listen((value) => playingNotificationSound.value = value);
    if (Platform.isWindows) windowManager.addListener(this);
  }

  @override
  void onWindowFocus() => _toastTheme?.value = ToastPreviewTheme.read();

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
                  if (Platform.isWindows || Platform.isLinux)
                    Obx(() => SettingsSwitch(
                      onChanged: (bool val) async {
                        SettingsSvc.settings.windowsTaskbarBadge.value = val;
                        await SettingsSvc.settings.saveOneAsync('windowsTaskbarBadge');
                        ChatsSvc.unreadCount.refresh();  // Trigger listener
                      },
                      initialVal: SettingsSvc.settings.windowsTaskbarBadge.value,
                      title: Platform.isLinux ? "Launcher Badge" : "Taskbar Badge",
                      subtitle: Platform.isLinux
                          ? "Show the unread count on the app's dock or launcher icon"
                          : "Enable badge on taskbar icon for new messages",
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
                            PlatformFile? platformFile = await FilePicker.pickFile(type: FileType.audio);
                            if (platformFile != null) {
                              String path = join(FilesystemSvc.soundsPath, "notification-${platformFile.name}");
                              await File(path).create(recursive: true);
                              await File(path).writeAsBytes(await platformFile.readAsBytes());
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
                          title: "Notification Layout",
                          subtitle: "Customize the buttons on message notifications. Drag an action to reorder it. "
                              "Tapbacks require Private API."
                              "${Platform.isLinux ? " GNOME shows up to 3." : ""}",
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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (Platform.isWindows)
                                    Obx(() {
                                      final showReplyField = SettingsSvc.settings.showReplyField.value;
                                      // Turning it on takes a button slot, so it can't while every slot is an action
                                      final blocked = !showReplyField &&
                                          SettingsSvc.settings.actionList.length >=
                                              Settings.maxNotificationActions(false)!;
                                      return GrayedOut(
                                        grayed: blocked,
                                        child: SettingsSwitch(
                                          initialVal: showReplyField,
                                          onChanged: _setReplyField,
                                          leading: const SettingsLeadingIcon(
                                            iosIcon: CupertinoIcons.arrowshape_turn_up_left,
                                            materialIcon: Icons.reply_outlined,
                                            containerColor: Colors.orange,
                                          ),
                                          title: "Show Reply Field",
                                          subtitle: blocked
                                              ? "Windows allows 5 buttons, and all 5 are actions. Remove one to show "
                                                  "the reply field."
                                              : "Show a reply field in the notification. This counts as one of your "
                                                  "actions.",
                                        ),
                                      );
                                    }),
                                  Obx(() {
                                    final actions = SettingsSvc.settings.actionList.toList();
                                    final showReplyField = SettingsSvc.settings.showReplyField.value;
                                    final max = Settings.maxNotificationActions(showReplyField);
                                    return AddNotificationAction(
                                      actions: actions,
                                      toast: Platform.isWindows ? _toastTheme!.value : ToastPreviewTheme.fromAppTheme(context),
                                      fullMessage: max == null || actions.length < max
                                          ? null
                                          : showReplyField
                                              ? "Windows allows 5 buttons, including the reply field. Remove an "
                                                  "action or the reply field to add another."
                                              : "Windows allows 5 buttons. Remove an action to add another.",
                                    );
                                  }),
                                  if (!Platform.isWindows)
                                    // Linux notifications look different on every desktop, so there's no preview
                                    Padding(
                                      padding: const EdgeInsets.all(15),
                                      child: Obx(() {
                                        final papi = SettingsSvc.settings.enablePrivateAPI.value;
                                        final actions = SettingsSvc.settings.actionList.toList();
                                        final toast = ToastPreviewTheme.fromAppTheme(context);
                                        return _hideTooltipsWhileDragging(ReorderableWrap(
                                          needsLongPressDraggable: false,
                                          spacing: 10,
                                          runSpacing: 10,
                                          alignment: WrapAlignment.center,
                                          onReorderStarted: (_) => _dragging.value = true,
                                          onNoReorder: (_) => _dragging.value = false,
                                          onReorder: (oldIndex, newIndex) => _reorder(actions, oldIndex, newIndex),
                                          buildDraggableFeedback: _dragFeedback,
                                          children: [
                                            for (final action in actions)
                                              NotificationActionButton(
                                                action,
                                                key: ValueKey(action),
                                                toast: toast,
                                                width: 90,
                                                height: 56,
                                                glyphSize: action == "Mark Read" ? 16 : 22,
                                                padding: const EdgeInsets.symmetric(horizontal: 9),
                                                sends: _sends(action, papi),
                                                dragging: _dragging,
                                                onRemove: () => _remove(actions, action),
                                              ),
                                          ],
                                        ));
                                      }),
                                    ),
                                ],
                              ),
                            ),
                            if (Platform.isWindows)
                              Obx(() {
                                context.width;
                                NavigationSvc.listener.value;
                                final papi = SettingsSvc.settings.enablePrivateAPI.value;
                                final actions = SettingsSvc.settings.actionList.toList();
                                final showReplyField = SettingsSvc.settings.showReplyField.value;
                                final toast = _toastTheme!.value;
                                const double margin = 20;
                                final double size = min(NavigationSvc.width(context) / 2, 400) - 2 * margin;
                                final int numActions = actions.length;
                                // "Mark Read" wraps onto two lines once 4 buttons share the row
                                final bool tall = actions.contains("Mark Read") && numActions > 3;
                                final double buttonHeight = size * (tall ? 0.13 : 0.09);
                                final double gap = size * 0.02;
                                final double rowWidth = size * 0.92;
                                final double buttonWidth =
                                    numActions == 0 ? 0 : (rowWidth - (numActions - 1) * gap) / numActions;
                                return SizedBox(
                                  width: NavigationSvc.width(context) > 1500 ? 800 : size + 2 * margin,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: AnimatedContainer(
                                      duration: _animation,
                                      curve: Curves.easeInOut,
                                      height: size /
                                          3 *
                                          (numActions == 0
                                              ? (showReplyField ? 1.3 : 0.9)
                                              : tall
                                                  ? (showReplyField ? 1.83 : 1.41)
                                                  : (showReplyField ? 1.72 : 1.28)),
                                      width: size,
                                      margin: const EdgeInsets.symmetric(vertical: margin / 2, horizontal: margin),
                                      decoration: BoxDecoration(
                                        color: toast.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: toast.border),
                                      ),
                                      child: Stack(
                                        clipBehavior: Clip.none,
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
                                            child: Text(
                                              "BlueBubbles",
                                              style: context.textTheme.bodyMedium!
                                                  .copyWith(fontSize: size * 0.0305, color: toast.text),
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
                                              style: context.textTheme.bodyMedium!
                                                  .copyWith(fontSize: size * 0.036, color: toast.text),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.182,
                                            left: size * 0.216,
                                            child: Text(
                                              "Message notifications will look like this.",
                                              style: context.textTheme.bodyMedium!
                                                  .copyWith(fontSize: size * 0.036, color: toast.subtext),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.3,
                                            left: size * 0.04,
                                            child: _fade(
                                              showReplyField,
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: toast.button,
                                                  borderRadius: BorderRadius.circular(5),
                                                  border: Border(
                                                    bottom: BorderSide(color: toast.text.withValues(alpha: 0.5)),
                                                  ),
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: size * 0.02, vertical: size * 0.016),
                                                height: size * 0.09,
                                                width: size * 0.92 * 0.82,
                                                child: Text("Type a reply...",
                                                    style: context.textTheme.bodyMedium!
                                                        .copyWith(fontSize: size * 0.038, color: toast.subtext)),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.3,
                                            right: size * 0.04,
                                            child: _fade(
                                              showReplyField,
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: toast.button,
                                                  borderRadius: BorderRadius.circular(5),
                                                ),
                                                height: size * 0.09,
                                                width: size * 0.92 * 0.15,
                                                child: Center(
                                                  child: Text("Reply",
                                                      style: context.textTheme.bodyMedium!.copyWith(
                                                          fontSize: size * 0.038,
                                                          color: toast.text.withValues(alpha: 0.4))),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: size * 0.035,
                                            right: size * 0.15,
                                            child: Icon(Icons.more_horiz, size: size * 0.04, color: toast.text),
                                          ),
                                          Positioned(
                                            top: size * 0.035,
                                            right: size * 0.05,
                                            child: Icon(Icons.close_rounded, size: size * 0.04, color: toast.text),
                                          ),
                                          AnimatedPositioned(
                                            duration: _animation,
                                            curve: Curves.easeInOut,
                                            left: size * 0.04,
                                            bottom: size * 0.04,
                                            height: buttonHeight,
                                            width: rowWidth,
                                            child: _hideTooltipsWhileDragging(ReorderableRow(
                                              needsLongPressDraggable: false,
                                              // Else it borrows the settings page's controller, and a drag throws
                                              // when it scrolls
                                              ignorePrimaryScrollController: true,
                                              mainAxisSize: MainAxisSize.min,
                                              onReorderStarted: (_) => _dragging.value = true,
                                              onNoReorder: (_) => _dragging.value = false,
                                              onReorder: (oldIndex, newIndex) => _reorder(actions, oldIndex, newIndex),
                                              buildDraggableFeedback: _dragFeedback,
                                              children: [
                                                for (final (i, action) in actions.indexed)
                                                  Padding(
                                                    key: ValueKey(action),
                                                    padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                                                    child: NotificationActionButton(
                                                      action,
                                                      toast: toast,
                                                      width: buttonWidth,
                                                      height: buttonHeight,
                                                      // Windows draws button images at 16px on a 364px-wide
                                                      // notification
                                                      glyphSize:
                                                          action == "Mark Read" ? size * 0.037 : size * 16 / 364,
                                                      padding: EdgeInsets.symmetric(
                                                          vertical: size * 0.01, horizontal: size * 0.02),
                                                      sends: _sends(action, papi),
                                                      dragging: _dragging,
                                                      onRemove: () => _remove(actions, action),
                                                    ),
                                                  ),
                                              ],
                                            )),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
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

  static const Duration _animation = Duration(milliseconds: 200);

  static void _remove(List<String> actions, String action) =>
      SettingsSvc.settings.setNotificationActions(actions.where((a) => a != action).toList());

  void _reorder(List<String> actions, int oldIndex, int newIndex) {
    _dragging.value = false;
    SettingsSvc.settings.setNotificationActions(actions..insert(newIndex, actions.removeAt(oldIndex)));
  }

  /// Whether [action] makes it onto the real notification: tapbacks need Private API, and emoji a server that sends
  /// them
  static bool _sends(String action, bool papi) =>
      action == "Mark Read" ||
      (papi && (ReactionTypes.toList().contains(action) || SettingsSvc.serverDetails.supportsEmojiTapbacks));

  final ValueNotifier<bool> _dragging = ValueNotifier(false);

  /// No "Drag to reorder" tooltips while dragging. The list is the builder's child, so it isn't rebuilt mid-drag.
  Widget _hideTooltipsWhileDragging(Widget list) => ValueListenableBuilder<bool>(
        valueListenable: _dragging,
        builder: (context, dragging, child) => TooltipVisibility(visible: !dragging, child: child!),
        child: list,
      );

  static Widget _dragFeedback(BuildContext context, BoxConstraints constraints, Widget child) =>
      Material(color: Colors.transparent, child: TooltipVisibility(visible: false, child: child));

  /// The reply field takes one of the notification's button slots, so turning it on drops an action past the limit
  Future<void> _setReplyField(bool shown) async {
    SettingsSvc.settings.showReplyField.value = shown;
    await SettingsSvc.settings.saveOneAsync('showReplyField');
    final max = Settings.maxNotificationActions(shown)!;
    final actions = SettingsSvc.settings.actionList;
    if (actions.length > max) await SettingsSvc.settings.setNotificationActions(actions.take(max).toList());
  }

  Widget _fade(bool shown, Widget child) =>
      AnimatedOpacity(opacity: shown ? 1 : 0, duration: _animation, curve: Curves.easeInOut, child: child);

  @override
  void dispose() {
    if (Platform.isWindows) windowManager.removeListener(this);
    _dragging.dispose();
    notificationPlayer.dispose();

    super.dispose();
  }
}
