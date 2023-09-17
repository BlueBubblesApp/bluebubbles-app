import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/tasker_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/scheduling/message_reminders_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/backup_restore_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/services/network/backend_service.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/settings/pages/misc/about_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/message_view/attachment_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/conversation_list/chat_list_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/message_view/conversation_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/desktop/desktop_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/misc/misc_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/system/notification_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/private_api_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/redacted_mode_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/scheduling/scheduled_messages_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/theming_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/misc/troubleshoot_panel.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/tablet_mode_wrapper.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:universal_io/io.dart';

class SettingsPage extends StatefulWidget {
  SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends OptimizedState<SettingsPage> {
  final RxBool uploadingContacts = false.obs;
  final RxnDouble progress = RxnDouble();
  final RxnInt totalSize = RxnInt();

  @override
  void initState() {
    super.initState();

    eventDispatcher.stream.listen((event) {
      if (event.item1 == 'theme-update') {
        setState(() {});
      }
    });

    if (showAltLayoutContextless && backend.getRemoteService() != null) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        ns.pushAndRemoveSettingsUntil(
          context,
          ServerManagementPanel(),
              (route) => route.isFirst,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget nextIcon = Obx(() => ss.settings.skin.value != Skins.Material ? Icon(
      ss.settings.skin.value != Skins.Material ? CupertinoIcons.chevron_right : Icons.arrow_forward,
      color: context.theme.colorScheme.outline,
      size: iOS ? 18 : 24,
    ) : const SizedBox.shrink());

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Actions(
        actions: {
          GoBackIntent: GoBackAction(context),
        },
        child: Obx(() => Container(
          color: context.theme.colorScheme.background.themeOpacity(context),
          child: TabletModeWrapper(
            initialRatio: 0.4,
            minRatio: kIsDesktop || kIsWeb ? 0.2 : 0.33,
            maxRatio: 0.5,
            allowResize: true,
            left: SettingsScaffold(
                title: "Settings",
                initialHeader: kIsWeb ? "Server & Message Management" : "Profile",
                iosSubtitle: iosSubtitle,
                materialSubtitle: materialSubtitle,
                tileColor: tileColor,
                headerColor: headerColor,
                bodySlivers: [
                  SliverList(
                    delegate: SliverChildListDelegate(
                      <Widget>[
                        if (!kIsWeb)
                          SettingsSection(
                            backgroundColor: tileColor,
                            children: [
                              SettingsTile(
                                backgroundColor: tileColor,
                                title: ss.settings.redactedMode.value && ss.settings.hideContactInfo.value
                                    ? "User Name" : ss.settings.userName.value,
                                subtitle: ss.settings.redactedMode.value && ss.settings.hideContactInfo.value
                                    ? "User iCloud"
                                    : ss.settings.iCloudAccount.isEmpty
                                    ? "Unknown iCloud account"
                                    : ss.settings.iCloudAccount.value,
                                onTap: () {
                                  final nameController = TextEditingController(text: ss.settings.userName.value);
                                  done() {
                                    if (nameController.text.isEmpty) {
                                      showSnackbar("Error", "Enter a name!");
                                      return;
                                    }
                                    Get.back();
                                    ss.settings.userName.value = nameController.text;
                                    ss.settings.save();
                                  }
                                  showDialog(
                                    context: context,
                                    builder: (_) {
                                      return AlertDialog(
                                        actions: [
                                          TextButton(
                                            child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                            onPressed: () => Get.back(),
                                          ),
                                          TextButton(
                                            child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                            onPressed: () async {
                                              done.call();
                                            },
                                          ),
                                        ],
                                        content: TextField(
                                          controller: nameController,
                                          onSubmitted: (_) => done.call(),
                                          autofocus: true,
                                          decoration: const InputDecoration(
                                            labelText: "Name",
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        title: Text("User Profile Name", style: context.theme.textTheme.titleLarge),
                                        backgroundColor: context.theme.colorScheme.properSurface,
                                      );
                                    }
                                  );
                                },
                                leading: GestureDetector(
                                  onTap: () {
                                    final path = ss.settings.userAvatarPath.value;
                                    if (path != null) {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                              backgroundColor: context.theme.colorScheme.properSurface,
                                              title: Text(
                                                  "Profile Avatar",
                                                  style: context.theme.textTheme.titleLarge
                                              ),
                                              content: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "You already have a profile avatar set. What would you like to do?",
                                                    style: context.theme.textTheme.bodyLarge,
                                                  ),
                                                ],
                                              ),
                                              actions: <Widget>[
                                                TextButton(
                                                  child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                                TextButton(
                                                  child: Text("Reset", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                                  onPressed: () {
                                                    File file = File(path);
                                                    file.delete();
                                                    ss.settings.userAvatarPath.value = null;
                                                    ss.saveSettings();
                                                    Get.back();
                                                  },
                                                ),
                                                TextButton(
                                                  child: Text("Set New", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                    Navigator.of(context).push(
                                                      ThemeSwitcher.buildPageRoute(
                                                        builder: (context) => AvatarCrop(),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ]
                                          );
                                        },
                                      );
                                    } else {
                                      Navigator.of(context).push(
                                        ThemeSwitcher.buildPageRoute(
                                          builder: (context) => AvatarCrop(),
                                        ),
                                      );
                                    }
                                  },
                                  child: ContactAvatarWidget(
                                    handle: null,
                                    borderThickness: 0.1,
                                    editable: false,
                                    fontSize: 22,
                                    size: 50,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (!kIsWeb && backend.getRemoteService() != null)
                          SettingsHeader(
                              headerColor: headerColor,
                              tileColor: tileColor,
                              iosSubtitle: iosSubtitle,
                              materialSubtitle: materialSubtitle,
                              text: "Server & Message Management"),
                        if (backend.getRemoteService() != null)
                          SettingsSection(
                            backgroundColor: tileColor,
                            children: [
                              Obx(() {
                                String? subtitle;
                                switch (socket.state.value) {
                                  case SocketState.connected:
                                    subtitle = "Connected";
                                    break;
                                  case SocketState.disconnected:
                                    subtitle = "Disconnected";
                                    break;
                                  case SocketState.error:
                                    subtitle = "Error";
                                    break;
                                  case SocketState.connecting:
                                    subtitle = "Connecting...";
                                    break;
                                  default:
                                    subtitle = "Error";
                                    break;
                                }

                                return SettingsTile(
                                  backgroundColor: tileColor,
                                  title: "Connection & Server",
                                  subtitle: subtitle,
                                  onTap: () async {
                                    ns.pushAndRemoveSettingsUntil(
                                      context,
                                      ServerManagementPanel(),
                                          (route) => route.isFirst,
                                    );
                                  },
                                  onLongPress: () {
                                    Clipboard.setData(ClipboardData(text: http.origin));
                                    if (!Platform.isAndroid || (fs.androidInfo?.version.sdkInt ?? 0) < 33) {
                                      showSnackbar("Copied", "Server address copied to clipboard!");
                                    }
                                  },
                                  leading: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Material(
                                        shape: samsung ? SquircleBorder(
                                          side: BorderSide(
                                              color: getIndicatorColor(socket.state.value),
                                              width: 3.0
                                          ),
                                        ) : null,
                                        color: ss.settings.skin.value != Skins.Material
                                            ? getIndicatorColor(socket.state.value)
                                            : Colors.transparent,
                                        borderRadius: iOS
                                            ? BorderRadius.circular(5) : null,
                                        child: SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                            Icon(
                                              iOS
                                                  ? CupertinoIcons.antenna_radiowaves_left_right
                                                  : Icons.router,
                                              color:
                                              ss.settings.skin.value != Skins.Material ? Colors.white : Colors.grey,
                                              size: ss.settings.skin.value != Skins.Material ? 23 : 30,
                                            ),
                                            if (material)
                                              Positioned.fill(
                                                child: Align(
                                                    alignment: Alignment.bottomRight,
                                                    child:
                                                    getIndicatorIcon(socket.state.value, size: 15, showAlpha: false)),
                                              ),
                                          ]),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: nextIcon,
                                );
                              }),
                              if (backend.canSchedule())
                                Container(
                                  color: tileColor,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 65.0),
                                    child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                  ),
                                ),
                              if (backend.canSchedule())
                                SettingsTile(
                                  backgroundColor: tileColor,
                                  title: "Scheduled Messages",
                                  subtitle: "Schedule your server to send a message in the future or at set intervals",
                                  isThreeLine: true,
                                  onTap: () {
                                    ns.pushAndRemoveSettingsUntil(
                                      context,
                                      ScheduledMessagesPanel(),
                                          (route) => route.isFirst,
                                    );
                                  },
                                  trailing: nextIcon,
                                  leading: const SettingsLeadingIcon(
                                    iosIcon: CupertinoIcons.calendar_today,
                                    materialIcon: Icons.schedule_send_outlined,
                                  ),
                                ),
                              if (Platform.isAndroid)
                                Container(
                                  color: tileColor,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 65.0),
                                    child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                  ),
                                ),
                              if (Platform.isAndroid)
                                SettingsTile(
                                  backgroundColor: tileColor,
                                  title: "Message Reminders",
                                  subtitle: "View and manage your upcoming message reminders",
                                  onTap: () {
                                    ns.pushAndRemoveSettingsUntil(
                                      context,
                                      MessageRemindersPanel(),
                                          (route) => route.isFirst,
                                    );
                                  },
                                  trailing: nextIcon,
                                  leading: const SettingsLeadingIcon(
                                    iosIcon: CupertinoIcons.alarm,
                                    materialIcon: Icons.alarm,
                                  ),
                                ),
                            ],
                          ),
                        SettingsHeader(
                            headerColor: headerColor,
                            tileColor: tileColor,
                            iosSubtitle: iosSubtitle,
                            materialSubtitle: materialSubtitle,
                            text: "Appearance"),
                        SettingsSection(
                          backgroundColor: tileColor,
                          children: [
                            SettingsTile(
                              backgroundColor: tileColor,
                              title: "Appearance Settings",
                              subtitle: "${ss.settings.skin.value.toString().split(".").last}   |   ${AdaptiveTheme.of(context).mode.toString().split(".").last.capitalizeFirst!} Mode",
                              onTap: () {
                                ns.pushAndRemoveSettingsUntil(
                                  context,
                                  ThemingPanel(),
                                      (route) => route.isFirst,
                                );
                              },
                              trailing: nextIcon,
                              leading: const SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.paintbrush,
                                materialIcon: Icons.palette,
                              ),
                            ),
                          ],
                        ),
                        SettingsHeader(
                            headerColor: headerColor,
                            tileColor: tileColor,
                            iosSubtitle: iosSubtitle,
                            materialSubtitle: materialSubtitle,
                            text: "Application Settings"),
                        SettingsSection(
                          backgroundColor: tileColor,
                          children: [
                            SettingsTile(
                              backgroundColor: tileColor,
                              title: "Media Settings",
                              onTap: () {
                                ns.pushAndRemoveSettingsUntil(
                                  context,
                                  AttachmentPanel(),
                                      (route) => route.isFirst,
                                );
                              },
                              leading: const SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.paperclip,
                                materialIcon: Icons.attachment,
                              ),
                              trailing: nextIcon,
                            ),
                            Container(
                              color: tileColor,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 65.0),
                                child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                              ),
                            ),
                            SettingsTile(
                              backgroundColor: tileColor,
                              title: "Notification Settings",
                              onTap: () {
                                ns.pushAndRemoveSettingsUntil(
                                  context,
                                  NotificationPanel(),
                                      (route) => route.isFirst,
                                );
                              },
                              leading: const SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.bell,
                                materialIcon: Icons.notifications_on,
                              ),
                              trailing: nextIcon,
                            ),
                            Container(
                              color: tileColor,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 65.0),
                                child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                              ),
                            ),
                            SettingsTile(
                              backgroundColor: tileColor,
                              title: "Chat List Settings",
                              onTap: () {
                                ns.pushAndRemoveSettingsUntil(
                                  context,
                                  ChatListPanel(),
                                      (route) => route.isFirst,
                                );
                              },
                              leading: const SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.square_list,
                                materialIcon: Icons.list,
                              ),
                              trailing: nextIcon,
                            ),
                            Container(
                              color: tileColor,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 65.0),
                                child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                              ),
                            ),
                            SettingsTile(
                              backgroundColor: tileColor,
                              title: "Conversation Settings",
                              onTap: () {
                                ns.pushAndRemoveSettingsUntil(
                                  context,
                                  ConversationPanel(),
                                      (route) => route.isFirst,
                                );
                              },
                              leading: const SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.chat_bubble,
                                materialIcon: Icons.sms,
                              ),
                              trailing: nextIcon,
                            ),
                            Container(
                              color: tileColor,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 65.0),
                                child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                              ),
                            ),
                            if (kIsDesktop)
                              SettingsTile(
                                backgroundColor: tileColor,
                                title: "Desktop Settings",
                                onTap: () {
                                  ns.pushAndRemoveSettingsUntil(
                                    context,
                                    DesktopPanel(),
                                        (route) => route.isFirst,
                                  );
                                },
                                leading: const SettingsLeadingIcon(
                                  iosIcon: CupertinoIcons.desktopcomputer,
                                  materialIcon: Icons.desktop_windows,
                                ),
                                trailing: nextIcon,
                              ),
                            if (kIsDesktop)
                              Container(
                                color: tileColor,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 65.0),
                                  child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                ),
                              ),
                            SettingsTile(
                              backgroundColor: tileColor,
                              title: "Misc and Advanced Settings",
                              onTap: () {
                                ns.pushAndRemoveSettingsUntil(
                                  context,
                                  MiscPanel(),
                                      (route) => route.isFirst,
                                );
                              },
                              leading: const SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.ellipsis_circle,
                                materialIcon: Icons.more_vert,
                              ),
                              trailing: nextIcon,
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
                            Obx(() => SettingsTile(
                              backgroundColor: tileColor,
                              title: "Private API Features",
                              subtitle:
                              "Private API ${ss.settings.enablePrivateAPI.value ? "Enabled" : "Disabled"}",
                              trailing: nextIcon,
                              onTap: () async {
                                ns.pushAndRemoveSettingsUntil(
                                  context,
                                  PrivateAPIPanel(),
                                      (route) => route.isFirst,
                                );
                              },
                              leading: SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.exclamationmark_shield,
                                materialIcon: Icons.gpp_maybe,
                                containerColor: getIndicatorColor(ss.settings.enablePrivateAPI.value
                                    ? SocketState.connected
                                    : SocketState.connecting),
                              ),
                            )),
                            Container(
                              color: tileColor,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 65.0),
                                child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                              ),
                            ),
                            Obx(() => SettingsTile(
                              backgroundColor: tileColor,
                              title: "Redacted Mode",
                              subtitle:
                              "Redacted Mode ${ss.settings.redactedMode.value ? "Enabled" : "Disabled"}",
                              trailing: nextIcon,
                              onTap: () async {
                                ns.pushAndRemoveSettingsUntil(
                                  context,
                                  RedactedModePanel(),
                                      (route) => route.isFirst,
                                );
                              },
                              leading: SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.wand_stars,
                                materialIcon: Icons.auto_fix_high,
                                containerColor: getIndicatorColor(ss.settings.redactedMode.value
                                    ? SocketState.connected
                                    : SocketState.connecting),
                              ),
                            )),
                            if (Platform.isAndroid)
                              Container(
                                color: tileColor,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 65.0),
                                  child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                ),
                              ),
                            if (Platform.isAndroid)
                              SettingsTile(
                                backgroundColor: tileColor,
                                title: "Tasker Integration",
                                subtitle: "Control integrations with Tasker",
                                trailing: nextIcon,
                                onTap: () async {
                                  ns.pushAndRemoveSettingsUntil(
                                    context,
                                    TaskerPanel(),
                                        (route) => route.isFirst,
                                  );
                                },
                                leading: const SettingsLeadingIcon(
                                  iosIcon: CupertinoIcons.bolt,
                                  materialIcon: Icons.electric_bolt_outlined,
                                ),
                              ),
                          ],
                        ),
                        SettingsHeader(
                            headerColor: headerColor,
                            tileColor: tileColor,
                            iosSubtitle: iosSubtitle,
                            materialSubtitle: materialSubtitle,
                            text: "About"),
                        SettingsSection(
                          backgroundColor: tileColor,
                          children: [
                            SettingsTile(
                              backgroundColor: tileColor,
                              title: "About & Links",
                              subtitle: "Donate, Rate, Changelog, & More",
                              onTap: () {
                                ns.pushAndRemoveSettingsUntil(
                                  context,
                                  AboutPanel(),
                                      (route) => route.isFirst,
                                );
                              },
                              trailing: nextIcon,
                              leading: const SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.info_circle,
                                materialIcon: Icons.info,
                              ),
                            ),
                          ],
                        ),
                        SettingsHeader(
                            headerColor: headerColor,
                            tileColor: tileColor,
                            iosSubtitle: iosSubtitle,
                            materialSubtitle: materialSubtitle,
                            text: "Backup and Reset"),
                        SettingsSection(
                            backgroundColor: tileColor,
                            children: [
                              if (backend.getRemoteService() != null)
                                SettingsTile(
                                  backgroundColor: tileColor,
                                  onTap: () {
                                    ns.pushAndRemoveSettingsUntil(
                                      context,
                                      BackupRestorePanel(),
                                          (route) => route.isFirst,
                                    );
                                  },
                                  trailing: nextIcon,
                                  leading: const SettingsLeadingIcon(
                                    iosIcon: CupertinoIcons.cloud_upload,
                                    materialIcon: Icons.backup,
                                  ),
                                  title: "Backup & Restore",
                                  subtitle: "Backup and restore all app settings and custom themes",
                                ),
                              if (backend.getRemoteService() != null)
                                Container(
                                  color: tileColor,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 65.0),
                                    child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                  ),
                                ),
                              if (!kIsWeb && !kIsDesktop)
                                SettingsTile(
                                  backgroundColor: tileColor,
                                  onTap: () async {
                                    void closeDialog() {
                                      Get.closeAllSnackbars();
                                      Navigator.of(context).pop();
                                      Future.delayed(const Duration(milliseconds: 400), ()
                                      {
                                        progress.value = null;
                                        totalSize.value = null;
                                      });
                                    }

                                    showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                            backgroundColor: context.theme.colorScheme.properSurface,
                                            title: Text("Uploading contacts...", style: context.theme.textTheme.titleLarge),
                                            content: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  Obx(() => Text(
                                                    '${progress.value != null && totalSize.value != null ? getSizeString(progress.value! * totalSize.value! / 1000) : ""} / ${getSizeString((totalSize.value ?? 0).toDouble() / 1000)} (${((progress.value ?? 0) * 100).floor()}%)',
                                                    style: context.theme.textTheme.bodyLarge,
                                                  ),
                                                  ),
                                                  const SizedBox(height: 10.0),
                                                  Obx(() => LinearProgressIndicator(
                                                    backgroundColor: context.theme.colorScheme.outline,
                                                    value: progress.value,
                                                    minHeight: 5,
                                                    valueColor:
                                                    AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                                  ),
                                                  ),
                                                  const SizedBox(
                                                    height: 15.0,
                                                  ),
                                                  Obx(() => Text(
                                                    progress.value == 1 ? "Upload Complete!" : "You can close this dialog. Contacts will continue to upload in the background.",
                                                    textAlign: TextAlign.center,
                                                    style: context.theme.textTheme.bodyLarge,
                                                  ),
                                                  ),
                                                ]),
                                            actions: [
                                              Obx(() => uploadingContacts.value
                                                  ? Container(height: 0, width: 0)
                                                  : TextButton(
                                                child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                                onPressed: () async {
                                                  closeDialog.call();
                                                },
                                              ),
                                              ),
                                            ]
                                        )
                                    );

                                    final contacts = <Map<String, dynamic>>[];
                                    for (Contact c in cs.contacts) {
                                      var map = c.toMap();
                                      contacts.add(map);
                                    }
                                    http.createContact(contacts, onSendProgress: (count, total) {
                                      uploadingContacts.value = true;
                                      progress.value = count / total;
                                      totalSize.value = total;
                                      if (progress.value == 1.0) {
                                        uploadingContacts.value = false;
                                        showSnackbar("Notice", "Successfully exported contacts to server");
                                      }
                                    }).catchError((err) {
                                      if (err is Response) {
                                        Logger.error(err.data["error"]["message"].toString());
                                      } else {
                                        Logger.error(err.toString());
                                      }

                                      closeDialog.call();
                                      showSnackbar("Error", "Failed to export contacts to server");
                                      return Response(requestOptions: RequestOptions(path: ''));
                                    });
                                  },
                                  leading: const SettingsLeadingIcon(
                                    iosIcon: CupertinoIcons.group,
                                    materialIcon: Icons.contacts,
                                  ),
                                  title: "Export Contacts",
                                  subtitle: "Send contacts to server for use on webapp and desktop app",
                                ),
                              if (!kIsWeb && !kIsDesktop)
                                Container(
                                  color: tileColor,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 65.0),
                                    child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                  ),
                                ),
                              SettingsTile(
                                backgroundColor: tileColor,
                                onTap: () {
                                  showDialog(
                                    barrierDismissible: false,
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text(
                                          "Are you sure?",
                                          style: context.theme.textTheme.titleLarge,
                                        ),
                                        content: Text(
                                          "If you just need to free up some storage, you can remove all downloaded attachments with the button below.",
                                          style: context.theme.textTheme.bodyLarge,
                                        ),
                                        backgroundColor: context.theme.colorScheme.properSurface,
                                        actions: <Widget>[
                                          if (!kIsWeb)
                                            TextButton(
                                              child: Text("Remove Attachments", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                              onPressed: () async {
                                                final dir = Directory("${fs.appDocDir.path}/attachments");
                                                await dir.delete(recursive: true);
                                                showSnackbar("Success", "Deleted cached attachments");
                                              },
                                            ),
                                          TextButton(
                                            child: Text("No", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                            onPressed: () {
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
                                              themeBox.putMany(ts.defaultThemes);
                                              await ts.changeTheme(context);
                                              Get.offAll(() => WillPopScope(
                                                onWillPop: () async => false,
                                                child: TitleBarWrapper(child: SetupView()),
                                              ), duration: Duration.zero, transition: Transition.noTransition);
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                leading: const SettingsLeadingIcon(
                                  iosIcon: CupertinoIcons.floppy_disk,
                                  materialIcon: Icons.storage,
                                ),
                                title: kIsWeb ? "Logout" : "Reset",
                                subtitle: kIsWeb ? null : "Resets the app to default settings",
                              ),
                              Container(
                                color: tileColor,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 65.0),
                                  child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                                ),
                              ),
                              SettingsTile(
                                backgroundColor: tileColor,
                                onTap: () async {
                                  ns.pushAndRemoveSettingsUntil(
                                    context,
                                    TroubleshootPanel(),
                                        (route) => route.isFirst,
                                  );
                                },
                                leading: const SettingsLeadingIcon(
                                  iosIcon: CupertinoIcons.question_circle,
                                  materialIcon: Icons.help_outline,
                                ),
                                title: "Troubleshooting",
                                trailing: nextIcon,
                              ),
                            ]
                        ),
                      ],
                    ),
                  ),
                ]
            ),
            right: LayoutBuilder(builder: (context, constraints) {
              ns.maxWidthSettings = constraints.maxWidth;
              return WillPopScope(
                onWillPop: () async {
                  Get.until((route) {
                    if (route.settings.name == "initial") {
                      Get.back();
                    } else {
                      Get.back(id: 3);
                    }
                    return true;
                  }, id: 3);
                  return false;
                },
                child: Navigator(
                  key: Get.nestedKey(3),
                  onPopPage: (route, _) {
                    route.didPop(false);
                    return false;
                  },
                  pages: [
                    CupertinoPage(
                        name: "initial",
                        child: Scaffold(
                            backgroundColor: ss.settings.skin.value != Skins.iOS ? tileColor : headerColor,
                            body: Center(
                              child: Text("Select a settings page from the list",
                                  style: context.theme.textTheme.bodyLarge),
                            ))),
                  ],
                ),
              );
            }),
          ),
        )
      )),
    );
  }
}
