import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/notification_providers_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/advanced/tasker_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/profile/profile_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/scheduling/message_reminders_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/backup_restore_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/next_button.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
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
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/tablet_mode_wrapper.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:get/get.dart' hide Response;
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  SettingsPage({
    super.key,
    this.initialPage,
  });

  final Widget? initialPage;

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

    if (showAltLayoutContextless) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        ns.pushAndRemoveSettingsUntil(
          context,
          widget.initialPage ?? ServerManagementPanel(),
          (route) => route.isFirst,
        );
      });
    } else if (widget.initialPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        ns.pushSettings(
          context,
          widget.initialPage!,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value
            ? Colors.transparent
            : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness:
            context.theme.colorScheme.brightness.opposite,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Actions(
          actions: {
            GoBackIntent: GoBackAction(context),
          },
          child: Obx(() => Container(
                color:
                    context.theme.colorScheme.background.themeOpacity(context),
                child: TabletModeWrapper(
                  initialRatio: 0.4,
                  minRatio: kIsDesktop || kIsWeb ? 0.2 : 0.33,
                  maxRatio: 0.5,
                  allowResize: true,
                  left: SettingsScaffold(
                      title: "Settings",
                      initialHeader:
                          kIsWeb ? "Server & Message Management" : (!iOS || kIsDesktop) ? "Profile" : null,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      tileColor: tileColor,
                      headerColor: headerColor,
                      bodySlivers: [
                        SliverList(
                          delegate: SliverChildListDelegate(
                            <Widget>[
                              if (!kIsWeb && (!iOS || kIsDesktop))
                                SettingsSection(
                                  backgroundColor: tileColor,
                                  children: [
                                    SettingsTile(
                                      backgroundColor: tileColor,
                                      title: ss.settings.redactedMode.value &&
                                              ss.settings.hideContactInfo.value
                                          ? "User Name"
                                          : ss.settings.userName.value,
                                      subtitle: "Tap to view more details",
                                      onTap: () {
                                        ns.pushAndRemoveSettingsUntil(
                                          context,
                                          ProfilePanel(),
                                          (route) => route.isFirst,
                                        );
                                      },
                                      leading: ContactAvatarWidget(
                                        handle: null,
                                        borderThickness: 0.1,
                                        editable: false,
                                        fontSize: 22,
                                        size: 50,
                                      ),
                                      trailing: const NextButton(),
                                    ),
                                  ],
                                ),
                              if (!kIsWeb)
                                SettingsHeader(
                                    iosSubtitle: iosSubtitle,
                                    materialSubtitle: materialSubtitle,
                                    text: "Server & Message Management"),
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
                                        subtitle = "Connecting";
                                        break;
                                      default:
                                        subtitle = "Error";
                                        break;
                                    }

                                    return SettingsTile(
                                      backgroundColor: tileColor,
                                      title: "Connection & Server",
                                      onTap: () async {
                                        ns.pushAndRemoveSettingsUntil(
                                          context,
                                          ServerManagementPanel(),
                                          (route) => route.isFirst,
                                        );
                                      },
                                      onLongPress: () {
                                        Clipboard.setData(
                                            ClipboardData(text: http.origin));
                                        if (!Platform.isAndroid ||
                                            (fs.androidInfo?.version.sdkInt ??
                                                    0) <
                                                33) {
                                          showSnackbar("Copied",
                                              "Server address copied to clipboard!");
                                        }
                                      },
                                      leading: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Material(
                                            shape: samsung
                                                ? SquircleBorder(
                                                    side: BorderSide(
                                                        color:
                                                            getIndicatorColor(
                                                                socket.state
                                                                    .value),
                                                        width: 3.0),
                                                  )
                                                : null,
                                            color: ss.settings.skin.value !=
                                                    Skins.Material
                                                ? getIndicatorColor(
                                                    socket.state.value)
                                                : Colors.transparent,
                                            borderRadius: iOS
                                                ? BorderRadius.circular(6)
                                                : null,
                                            child: SizedBox(
                                              width: 30,
                                              height: 30,
                                              child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    Icon(
                                                      iOS
                                                          ? CupertinoIcons
                                                              .antenna_radiowaves_left_right
                                                          : Icons.router,
                                                      color: ss.settings.skin
                                                                  .value !=
                                                              Skins.Material
                                                          ? Colors.white
                                                          : Colors.grey,
                                                      size: ss.settings.skin
                                                                  .value !=
                                                              Skins.Material
                                                          ? 21
                                                          : 28,
                                                    ),
                                                    if (material)
                                                      Positioned.fill(
                                                        child: Align(
                                                            alignment: Alignment
                                                                .bottomRight,
                                                            child:
                                                                getIndicatorIcon(
                                                                    socket.state
                                                                        .value,
                                                                    size: 12,
                                                                    showAlpha:
                                                                        false)),
                                                      ),
                                                  ]),
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            subtitle,
                                            style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.colorScheme.outline.withOpacity(0.85)),
                                          ),
                                          const SizedBox(width: 5),
                                          const NextButton(),
                                        ]
                                      )
                                    );
                                  }),
                                  if (ss.serverDetailsSync().item4 >= 205)
                                    const SettingsDivider(),
                                  if (ss.serverDetailsSync().item4 >= 205)
                                    SettingsTile(
                                      backgroundColor: tileColor,
                                      title: "Scheduled Messages",
                                      onTap: () {
                                        ns.pushAndRemoveSettingsUntil(
                                          context,
                                          ScheduledMessagesPanel(),
                                          (route) => route.isFirst,
                                        );
                                      },
                                      trailing: const NextButton(),
                                      leading: const SettingsLeadingIcon(
                                        iosIcon: CupertinoIcons.calendar,
                                        materialIcon:
                                            Icons.schedule_send_outlined,
                                        containerColor: Colors.redAccent,
                                      ),
                                    ),
                                  if (Platform.isAndroid)
                                    const SettingsDivider(),
                                  if (Platform.isAndroid)
                                    SettingsTile(
                                      backgroundColor: tileColor,
                                      title: "Message Reminders",
                                      onTap: () {
                                        ns.pushAndRemoveSettingsUntil(
                                          context,
                                          MessageRemindersPanel(),
                                          (route) => route.isFirst,
                                        );
                                      },
                                      trailing: const NextButton(),
                                      leading: const SettingsLeadingIcon(
                                        iosIcon: CupertinoIcons.alarm_fill,
                                        materialIcon: Icons.alarm,
                                        containerColor: Colors.blueAccent,
                                      ),
                                    ),
                                ],
                              ),
                              SettingsHeader(
                                  iosSubtitle: iosSubtitle,
                                  materialSubtitle: materialSubtitle,
                                  text: "Appearance"),
                              SettingsSection(
                                backgroundColor: tileColor,
                                children: [
                                  SettingsTile(
                                    backgroundColor: tileColor,
                                    title: "Appearance Settings",
                                    onTap: () {
                                      ns.pushAndRemoveSettingsUntil(
                                        context,
                                        ThemingPanel(),
                                        (route) => route.isFirst,
                                      );
                                    },
                                    trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "${ss.settings.skin.value.toString().split(".").last}  |  ${AdaptiveTheme.of(context).mode.toString().split(".").last.capitalizeFirst!}",
                                            style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.colorScheme.outline.withOpacity(0.85)),
                                          ),
                                          const SizedBox(width: 5),
                                          const NextButton(),
                                        ]
                                      ),
                                    leading: const SettingsLeadingIcon(
                                        iosIcon: CupertinoIcons.paintbrush_fill,
                                        materialIcon: Icons.palette,
                                        containerColor: Colors.blueGrey),
                                  ),
                                ],
                              ),
                              SettingsHeader(
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
                                        iosIcon: CupertinoIcons.photo_fill,
                                        materialIcon: Icons.attachment,
                                        iconSize: 18,
                                        containerColor:
                                            Colors.deepPurpleAccent),
                                    trailing: const NextButton(),
                                  ),
                                  const SettingsDivider(),
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
                                      iosIcon: CupertinoIcons.bell_fill,
                                      materialIcon: Icons.notifications_on,
                                      containerColor: Colors.redAccent,
                                    ),
                                    trailing: const NextButton(),
                                  ),
                                  const SettingsDivider(),
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
                                      iosIcon: CupertinoIcons.square_list_fill,
                                      materialIcon: Icons.list,
                                      containerColor: Colors.blueAccent,
                                    ),
                                    trailing: const NextButton(),
                                  ),
                                  const SettingsDivider(),
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
                                      iosIcon: CupertinoIcons.chat_bubble_fill,
                                      materialIcon: Icons.sms,
                                      containerColor: Colors.green,
                                    ),
                                    trailing: const NextButton(),
                                  ),
                                  const SettingsDivider(),
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
                                      trailing: const NextButton(),
                                    ),
                                  if (kIsDesktop)
                                    const SettingsDivider(),
                                  SettingsTile(
                                    backgroundColor: tileColor,
                                    title: "More Settings",
                                    onTap: () {
                                      ns.pushAndRemoveSettingsUntil(
                                        context,
                                        MiscPanel(),
                                        (route) => route.isFirst,
                                      );
                                    },
                                    leading: const SettingsLeadingIcon(
                                      iosIcon: CupertinoIcons.ellipsis_circle_fill,
                                      materialIcon: Icons.more_vert,
                                    ),
                                    trailing: const NextButton(),
                                  ),
                                ],
                              ),
                              SettingsHeader(
                                  iosSubtitle: iosSubtitle,
                                  materialSubtitle: materialSubtitle,
                                  text: "Advanced"),
                              SettingsSection(
                                backgroundColor: tileColor,
                                children: [
                                  Obx(() => SettingsTile(
                                        backgroundColor: tileColor,
                                        title: "Private API Features",
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              ss.settings.enablePrivateAPI.value ? ss.settings.serverPrivateAPI.value == false ? "Not Set Up" : "Enabled" : "Disabled",
                                              style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.colorScheme.outline.withOpacity(0.85)),
                                            ),
                                            const SizedBox(width: 5),
                                            const NextButton(),
                                          ]
                                        ),
                                        onTap: () async {
                                          ns.pushAndRemoveSettingsUntil(
                                            context,
                                            PrivateAPIPanel(),
                                            (route) => route.isFirst,
                                          );
                                        },
                                        leading: SettingsLeadingIcon(
                                          iosIcon: CupertinoIcons
                                              .exclamationmark_shield_fill,
                                          materialIcon: Icons.gpp_maybe,
                                          containerColor:
                                              ss.settings.enablePrivateAPI.value
                                                  ? ss.settings.serverPrivateAPI
                                                              .value ==
                                                          false
                                                      ? Colors.redAccent
                                                      : Colors.green
                                                  : Colors.amber,
                                        ),
                                      )),
                                  const SettingsDivider(),
                                  Obx(() => SettingsTile(
                                        backgroundColor: tileColor,
                                        title: "Redacted Mode",
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              ss.settings.redactedMode.value ? "Enabled" : "Disabled",
                                              style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.colorScheme.outline.withOpacity(0.85)),
                                            ),
                                            const SizedBox(width: 5),
                                            const NextButton(),
                                          ]
                                        ),
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
                                          containerColor:
                                              ss.settings.redactedMode.value
                                                  ? Colors.green
                                                  : Colors.redAccent,
                                        ),
                                      )),
                                  if (Platform.isAndroid)
                                    const SettingsDivider(),
                                  if (Platform.isAndroid)
                                    SettingsTile(
                                      backgroundColor: tileColor,
                                      title: "Tasker Integration",
                                      trailing: const NextButton(),
                                      onTap: () async {
                                        ns.pushAndRemoveSettingsUntil(
                                          context,
                                          TaskerPanel(),
                                          (route) => route.isFirst,
                                        );
                                      },
                                      leading: const SettingsLeadingIcon(
                                          iosIcon: CupertinoIcons.bolt_fill,
                                          materialIcon:
                                              Icons.electric_bolt_outlined,
                                          containerColor: Colors.orangeAccent),
                                    ),
                                  const SettingsDivider(),
                                  SettingsTile(
                                      backgroundColor: tileColor,
                                      title: "Notification Providers",
                                      trailing: const NextButton(),
                                      onTap: () async {
                                        ns.pushAndRemoveSettingsUntil(
                                            context,
                                            NotificationProvidersPanel(),
                                            (route) => route.isFirst);
                                      },
                                      leading: const SettingsLeadingIcon(
                                          iosIcon: CupertinoIcons.bell,
                                          materialIcon: Icons.notifications,
                                          containerColor: Colors.green)),
                                  const SettingsDivider(),
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
                                        iosIcon: CupertinoIcons.wrench_fill,
                                        materialIcon: Icons.adb,
                                        containerColor: Colors.blueAccent,
                                      ),
                                      title: "Developer Tools",
                                      subtitle: "View logs, troubleshoot bugs, and more",
                                      trailing: const NextButton(),
                                    )
                                ],
                              ),
                              SettingsHeader(
                                  iosSubtitle: iosSubtitle,
                                  materialSubtitle: materialSubtitle,
                                  text: "Backup and Restore"),
                              SettingsSection(
                                  backgroundColor: tileColor,
                                  children: [
                                    SettingsTile(
                                      backgroundColor: tileColor,
                                      onTap: () {
                                        ns.pushAndRemoveSettingsUntil(
                                          context,
                                          BackupRestorePanel(),
                                          (route) => route.isFirst,
                                        );
                                      },
                                      trailing: const NextButton(),
                                      leading: const SettingsLeadingIcon(
                                        iosIcon: CupertinoIcons.cloud_upload_fill,
                                        materialIcon: Icons.backup,
                                        containerColor: Colors.amber,
                                      ),
                                      title: "Backup & Restore",
                                      subtitle:
                                          "Backup and restore all app settings and custom themes",
                                    ),
                                    const SettingsDivider(),
                                    if (!kIsWeb && !kIsDesktop)
                                      SettingsTile(
                                        backgroundColor: tileColor,
                                        onTap: () async {
                                          void closeDialog() {
                                            Get.closeAllSnackbars();
                                            Navigator.of(context).pop();
                                            Future.delayed(
                                                const Duration(
                                                    milliseconds: 400), () {
                                              progress.value = null;
                                              totalSize.value = null;
                                            });
                                          }

                                          showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                      backgroundColor: context
                                                          .theme
                                                          .colorScheme
                                                          .properSurface,
                                                      title: Text(
                                                          "Uploading contacts...",
                                                          style: context
                                                              .theme
                                                              .textTheme
                                                              .titleLarge),
                                                      content: Column(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: <Widget>[
                                                            Obx(
                                                              () => Text(
                                                                '${progress.value != null && totalSize.value != null ? (progress.value! * totalSize.value! / 1000).getFriendlySize(withSuffix: false) : ""} / ${((totalSize.value ?? 0).toDouble() / 1000).getFriendlySize()} (${((progress.value ?? 0) * 100).floor()}%)',
                                                                style: context
                                                                    .theme
                                                                    .textTheme
                                                                    .bodyLarge,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 10.0),
                                                            Obx(
                                                              () =>
                                                                  LinearProgressIndicator(
                                                                backgroundColor:
                                                                    context
                                                                        .theme
                                                                        .colorScheme
                                                                        .outline,
                                                                value: progress
                                                                    .value,
                                                                minHeight: 5,
                                                                valueColor: AlwaysStoppedAnimation<
                                                                        Color>(
                                                                    context
                                                                        .theme
                                                                        .colorScheme
                                                                        .primary),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 15.0,
                                                            ),
                                                            Obx(
                                                              () => Text(
                                                                progress.value ==
                                                                        1
                                                                    ? "Upload Complete!"
                                                                    : "You can close this dialog. Contacts will continue to upload in the background.",
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: context
                                                                    .theme
                                                                    .textTheme
                                                                    .bodyLarge,
                                                              ),
                                                            ),
                                                          ]),
                                                      actions: [
                                                        Obx(
                                                          () =>
                                                              uploadingContacts
                                                                      .value
                                                                  ? Container(
                                                                      height: 0,
                                                                      width: 0)
                                                                  : TextButton(
                                                                      child: Text(
                                                                          "Close",
                                                                          style: context
                                                                              .theme
                                                                              .textTheme
                                                                              .bodyLarge!
                                                                              .copyWith(color: context.theme.colorScheme.primary)),
                                                                      onPressed:
                                                                          () async {
                                                                        closeDialog
                                                                            .call();
                                                                      },
                                                                    ),
                                                        ),
                                                      ]));

                                          final contacts =
                                              <Map<String, dynamic>>[];
                                          for (Contact c in cs.contacts) {
                                            var map = c.toMap();
                                            contacts.add(map);
                                          }
                                          http.createContact(contacts,
                                              onSendProgress: (count, total) {
                                            uploadingContacts.value = true;
                                            progress.value = count / total;
                                            totalSize.value = total;
                                            if (progress.value == 1.0) {
                                              uploadingContacts.value = false;
                                              showSnackbar("Notice",
                                                  "Successfully exported contacts to server");
                                            }
                                          }).catchError((err, stack) {
                                            if (err is Response) {
                                              Logger.error(
                                                  err.data["error"]["message"]
                                                      .toString(),
                                                  error: err,
                                                  trace: stack);
                                            } else {
                                              Logger.error(
                                                  "Failed to create contact!",
                                                  error: err,
                                                  trace: stack);
                                            }

                                            closeDialog.call();
                                            showSnackbar("Error",
                                                "Failed to export contacts to server");
                                            return Response(
                                                requestOptions:
                                                    RequestOptions(path: ''));
                                          });
                                        },
                                        leading: const SettingsLeadingIcon(
                                            iosIcon: CupertinoIcons.group_solid,
                                            materialIcon: Icons.contacts,
                                            containerColor: Colors.green),
                                        title: "Export Contacts",
                                        subtitle:
                                            "Send contacts to server for use on the desktop app",
                                      ),
                                  ]),
                              SettingsHeader(
                                  iosSubtitle: iosSubtitle,
                                  materialSubtitle: materialSubtitle,
                                  text: "About & Links"),
                              SettingsSection(
                                backgroundColor: tileColor,
                                children: [
                                  if (!kIsWeb && (Platform.isAndroid || Platform.isWindows))
                                    SettingsTile(
                                      title: "Leave Us a Review",
                                      subtitle: "Enjoying the app? Leave us a review on the ${Platform.isAndroid ? 'Google Play Store' : 'Microsoft Store'}!",
                                      onTap: () async {
                                        // Just open the listing for now. We don't want to actually open the dialog here.
                                        // If a review has been left, nothing will happen if tapped, which we don't want.
                                        final InAppReview inAppReview = InAppReview.instance;
                                        inAppReview.openStoreListing(microsoftStoreId: '9P3XF8KJ0LSM');
                                      },
                                      leading: const SettingsLeadingIcon(
                                        iosIcon: CupertinoIcons.star_fill,
                                        materialIcon: Icons.star,
                                        containerColor: Colors.blue,
                                      ),
                                      isThreeLine: false,
                                    ),
                                  if (!kIsWeb && (Platform.isAndroid || Platform.isWindows))
                                    const SettingsDivider(),
                                  SettingsTile(
                                    title: "Make a Donation",
                                    subtitle: "Support the developers by making a one-time or recurring donation to the BlueBubbles Team!",
                                    onTap: () async {
                                      await launchUrl(Uri(scheme: "https", host: "bluebubbles.app", path: "donate"), mode: LaunchMode.externalApplication);
                                    },
                                    leading: const SettingsLeadingIcon(
                                      iosIcon: CupertinoIcons.money_dollar_circle,
                                      materialIcon: Icons.attach_money,
                                      containerColor: Colors.green,
                                    ),
                                    isThreeLine: false,
                                  ),
                                  const SettingsDivider(),
                                  SettingsTile(
                                    title: "Join Our Discord",
                                    subtitle: "Join our Discord server to chat with other BlueBubbles users and the developers",
                                    onTap: () async {
                                      await launchUrl(Uri(scheme: "https", host: "discord.gg", path: "hbx7EhNFjp"), mode: LaunchMode.externalApplication);
                                    },
                                    leading: SettingsLeadingIcon(
                                      iosIcon: Icons.discord,
                                      materialIcon: Icons.discord,
                                      containerColor: HexColor('#7785CC'),
                                    ),
                                  ),
                                  const SettingsDivider(),
                                  SettingsTile(
                                    backgroundColor: tileColor,
                                    title: "About & More",
                                    subtitle: "Links, Changelog, & More",
                                    onTap: () {
                                      ns.pushAndRemoveSettingsUntil(
                                        context,
                                        AboutPanel(),
                                        (route) => route.isFirst,
                                      );
                                    },
                                    trailing: const NextButton(),
                                    leading: const SettingsLeadingIcon(
                                      iosIcon: CupertinoIcons.info_circle_fill,
                                      materialIcon: Icons.info,
                                      containerColor: Colors.blueAccent,
                                    ),
                                  ),
                                ],
                              ),
                              SettingsHeader(
                                  iosSubtitle: iosSubtitle,
                                  materialSubtitle: materialSubtitle,
                                  text: "Danger Zone"),
                              SettingsSection(
                                  backgroundColor: tileColor,
                                  children: [
                                    if (!kIsWeb)
                                      SettingsTile(
                                        backgroundColor: tileColor,
                                        onTap: () {
                                          showDialog(
                                            barrierDismissible: true,
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: Text(
                                                  "Are you sure?",
                                                  style: context
                                                      .theme.textTheme.titleLarge,
                                                ),
                                                content: Text(
                                                  "This will remove all attachments from this app. Recent attachments will be automatically re-downloaded when you enter a chat. This will not delete attachments from your server.",
                                                  style: context
                                                      .theme.textTheme.bodyLarge,
                                                ),
                                                backgroundColor: context.theme
                                                    .colorScheme.properSurface,
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: Text("No",
                                                        style: context.theme
                                                            .textTheme.bodyLarge!
                                                            .copyWith(
                                                                color: context
                                                                    .theme
                                                                    .colorScheme
                                                                    .primary)),
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                  ),
                                                  TextButton(
                                                    child: Text("Yes",
                                                        style: context.theme
                                                            .textTheme.bodyLarge!
                                                            .copyWith(
                                                                color: context
                                                                    .theme
                                                                    .colorScheme
                                                                    .primary)),
                                                    onPressed: () async {
                                                      final dir = Directory(
                                                          "${fs.appDocDir.path}/attachments");
                                                      await dir.delete(
                                                          recursive: true);
                                                      showSnackbar("Success",
                                                          "Deleted cached attachments");
                                                    }
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                        leading: SettingsLeadingIcon(
                                          iosIcon: CupertinoIcons.trash_slash_fill,
                                          materialIcon: Icons.delete_forever_outlined,
                                          containerColor: Colors.red[700],
                                        ),
                                        title: "Delete All Attachments",
                                        subtitle: "Remove all attachments from this app",
                                      ),
                                    if (!kIsWeb)
                                      const SettingsDivider(),
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
                                                style: context
                                                    .theme.textTheme.titleLarge,
                                              ),
                                              content: Text(
                                                "This will delete all app data, including your settings, messages, attachments, and more. This action cannot be undone. It is recommended that you take a backup of your settings before proceeding. This will also close the app once the process is complete.",
                                                style: context
                                                    .theme.textTheme.bodyLarge,
                                              ),
                                              backgroundColor: context.theme
                                                  .colorScheme.properSurface,
                                              actions: <Widget>[
                                                TextButton(
                                                  child: Text("No",
                                                      style: context.theme
                                                          .textTheme.bodyLarge!
                                                          .copyWith(
                                                              color: context
                                                                  .theme
                                                                  .colorScheme
                                                                  .primary)),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                                TextButton(
                                                  child: Text("Yes",
                                                      style: context.theme
                                                          .textTheme.bodyLarge!
                                                          .copyWith(
                                                              color: context
                                                                  .theme
                                                                  .colorScheme
                                                                  .primary)),
                                                  onPressed: () async {
                                                    fs.deleteDB();
                                                    socket.forgetConnection();
                                                    ss.settings = Settings();
                                                    await ss.settings.saveAsync();

                                                    await ss.prefs.clear();
                                                    await ss.prefs.setString("selected-dark", "OLED Dark");
                                                    await ss.prefs.setString("selected-light", "Bright White");
                                                    Database.themes.putMany(ts.defaultThemes);
                                                    
                                                    // Clear the FCM data from the database, shared preferences, and locally
                                                    await FCMData.deleteFcmData();

                                                    // Delete the Firebase FCM token
                                                    try {
                                                      if (fcm.token != null) {
                                                        await mcs.invokeMethod("firebase-delete-token");
                                                      }
                                                    } catch (e, s) {
                                                      Logger.error("Failed to delete Firebase FCM token", error: e, trace: s);
                                                    }

                                                    // Fully close the app
                                                    exit(0);
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      leading: SettingsLeadingIcon(
                                        iosIcon: CupertinoIcons.refresh_circled_solid,
                                        materialIcon: Icons.refresh_rounded,
                                        containerColor: Colors.red[700],
                                      ),
                                      title: kIsWeb ? "Logout" : "Reset App",
                                      subtitle: kIsWeb
                                          ? null
                                          : "Resets the app to default settings",
                                    ),
                                  ])
                            ],
                          ),
                        ),
                      ]),
                  right: LayoutBuilder(builder: (context, constraints) {
                    ns.maxWidthSettings = constraints.maxWidth;
                    return PopScope(
                      canPop: false,
                      onPopInvoked: (_) async {
                        Get.until((route) {
                          if (route.settings.name == "initial") {
                            Get.back();
                          } else {
                            Get.back(id: 3);
                          }
                          return true;
                        }, id: 3);
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
                                  backgroundColor:
                                      ss.settings.skin.value != Skins.iOS
                                          ? tileColor
                                          : headerColor,
                                  body: Center(
                                    child: Text(
                                        "Select a settings page from the list",
                                        style:
                                            context.theme.textTheme.bodyLarge),
                                  ))),
                        ],
                      ),
                    );
                  }),
                ),
              ))),
    );
  }
}
