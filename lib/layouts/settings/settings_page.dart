import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/settings/theme_helpers_mixin.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/dialogs/backup_restore_dialog.dart';
import 'package:bluebubbles/layouts/settings/pages/misc/about_panel.dart';
import 'package:bluebubbles/layouts/settings/pages/message_view/attachment_panel.dart';
import 'package:bluebubbles/layouts/settings/pages/conversation_list/chat_list_panel.dart';
import 'package:bluebubbles/layouts/settings/pages/message_view/conversation_panel.dart';
import 'package:bluebubbles/layouts/settings/pages/desktop/desktop_panel.dart';
import 'package:bluebubbles/layouts/settings/pages/misc/misc_panel.dart';
import 'package:bluebubbles/layouts/settings/pages/system/notification_panel.dart';
import 'package:bluebubbles/layouts/settings/pages/advanced/private_api_panel.dart';
import 'package:bluebubbles/layouts/settings/pages/advanced/redacted_mode_panel.dart';
import 'package:bluebubbles/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/layouts/settings/pages/theming/theming_panel.dart';
import 'package:bluebubbles/layouts/settings/pages/misc/troubleshoot_panel.dart';
import 'package:bluebubbles/layouts/setup/setup_view.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/layouts/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/layouts/wrappers/tablet_mode_wrapper.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/intents.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
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

class _SettingsPageState extends OptimizedState<SettingsPage> with ThemeHelpers {
  final RxBool uploadingContacts = false.obs;
  final RxnDouble progress = RxnDouble();
  final RxnInt totalSize = RxnInt();

  @override
  void initState() {
    super.initState();

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (event["type"] == 'theme-update') {
        setState(() {});
      }
    });

    if (showAltLayoutContextless) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        CustomNavigator.pushAndRemoveSettingsUntil(
          context,
          ServerManagementPanel(),
              (route) => route.isFirst,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget nextIcon = Obx(() => SettingsManager().settings.skin.value != Skins.Material ? Icon(
      SettingsManager().settings.skin.value != Skins.Material ? CupertinoIcons.chevron_right : Icons.arrow_forward,
      color: context.theme.colorScheme.outline,
      size: iOS ? 18 : 24,
    ) : const SizedBox.shrink());

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Actions(
        actions: {
          GoBackIntent: GoBackAction(context),
        },
        child: TabletModeWrapper(
          initialRatio: 0.4,
          minRatio: kIsDesktop || kIsWeb ? 0.2 : 0.33,
          maxRatio: 0.5,
          allowResize: true,
          left: SettingsScaffold(
              title: "Settings",
              initialHeader: "Server Management",
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
                          Obx(() {
                            String? subtitle;
                            switch (SocketManager().state.value) {
                              case SocketState.CONNECTED:
                                subtitle = "Connected";
                                break;
                              case SocketState.DISCONNECTED:
                                subtitle = "Disconnected";
                                break;
                              case SocketState.ERROR:
                                subtitle = "Error";
                                break;
                              case SocketState.CONNECTING:
                                subtitle = "Connecting...";
                                break;
                              case SocketState.FAILED:
                                subtitle = "Failed to connect";
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
                                CustomNavigator.pushAndRemoveSettingsUntil(
                                  context,
                                  ServerManagementPanel(),
                                      (route) => route.isFirst,
                                );
                              },
                              onLongPress: () {
                                Clipboard.setData(ClipboardData(text: SettingsManager().settings.serverAddress.value));
                                showSnackbar('Copied', "Address copied to clipboard");
                              },
                              leading: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Material(
                                    shape: samsung ? SquircleBorder(
                                      side: BorderSide(
                                          color: getIndicatorColor(SocketManager().state.value),
                                          width: 3.0
                                      ),
                                    ) : null,
                                    color: SettingsManager().settings.skin.value != Skins.Material
                                        ? getIndicatorColor(SocketManager().state.value)
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
                                          SettingsManager().settings.skin.value != Skins.Material ? Colors.white : Colors.grey,
                                          size: SettingsManager().settings.skin.value != Skins.Material ? 23 : 30,
                                        ),
                                        if (material)
                                          Positioned.fill(
                                            child: Align(
                                                alignment: Alignment.bottomRight,
                                                child:
                                                getIndicatorIcon(SocketManager().state.value, size: 15, showAlpha: false)),
                                          ),
                                      ]),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: nextIcon,
                            );
                          }),
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
                            subtitle: "${SettingsManager().settings.skin.value.toString().split(".").last}   |   ${AdaptiveTheme.of(context).mode.toString().split(".").last.capitalizeFirst!} Mode",
                            onTap: () {
                              CustomNavigator.pushAndRemoveSettingsUntil(
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
                              CustomNavigator.pushAndRemoveSettingsUntil(
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
                              CustomNavigator.pushAndRemoveSettingsUntil(
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
                              CustomNavigator.pushAndRemoveSettingsUntil(
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
                              CustomNavigator.pushAndRemoveSettingsUntil(
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
                                CustomNavigator.pushAndRemoveSettingsUntil(
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
                              CustomNavigator.pushAndRemoveSettingsUntil(
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
                          SettingsTile(
                            backgroundColor: tileColor,
                            title: "Private API Features",
                            subtitle:
                            "Private API ${SettingsManager().settings.enablePrivateAPI.value ? "Enabled" : "Disabled"}",
                            trailing: nextIcon,
                            onTap: () async {
                              CustomNavigator.pushAndRemoveSettingsUntil(
                                context,
                                PrivateAPIPanel(),
                                    (route) => route.isFirst,
                              );
                            },
                            leading: SettingsLeadingIcon(
                              iosIcon: CupertinoIcons.exclamationmark_shield,
                              materialIcon: Icons.gpp_maybe,
                              containerColor: getIndicatorColor(SettingsManager().settings.enablePrivateAPI.value
                                  ? SocketState.CONNECTED
                                  : SocketState.CONNECTING),
                            ),
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
                            title: "Redacted Mode",
                            subtitle:
                            "Redacted Mode ${SettingsManager().settings.redactedMode.value ? "Enabled" : "Disabled"}",
                            trailing: nextIcon,
                            onTap: () async {
                              CustomNavigator.pushAndRemoveSettingsUntil(
                                context,
                                RedactedModePanel(),
                                    (route) => route.isFirst,
                              );
                            },
                            leading: SettingsLeadingIcon(
                              iosIcon: CupertinoIcons.wand_stars,
                              materialIcon: Icons.auto_fix_high,
                              containerColor: getIndicatorColor(SettingsManager().settings.redactedMode.value
                                  ? SocketState.CONNECTED
                                  : SocketState.CONNECTING),
                            ),
                          ),
                        ],
                      ),
                      // SettingsTile(
                      //   title: "Message Scheduling",
                      //   trailing: Icon(Icons.arrow_forward_ios,
                      //       color: context.theme.primaryColor),
                      //   onTap: () async {
                      //     Navigator.of(context).push(
                      //       CupertinoPageRoute(
                      //         builder: (context) => SchedulingPanel(),
                      //       ),
                      //     );
                      //   },
                      // ),
                      // SettingsTile(
                      //   title: "Search",
                      //   trailing: Icon(Icons.arrow_forward_ios,
                      //       color: context.theme.primaryColor),
                      //   onTap: () async {
                      //     Navigator.of(context).push(
                      //       CupertinoPageRoute(
                      //         builder: (context) => SearchView(),
                      //       ),
                      //     );
                      //   },
                      // ),
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
                              CustomNavigator.pushAndRemoveSettingsUntil(
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
                            SettingsTile(
                              backgroundColor: tileColor,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => const BackupRestoreDialog(),
                                );
                              },
                              leading: const SettingsLeadingIcon(
                                iosIcon: CupertinoIcons.cloud_upload,
                                materialIcon: Icons.backup,
                              ),
                              title: "Backup & Restore",
                              subtitle: "Backup and restore all app settings",
                            ),
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
                                    if (Get.isSnackbarOpen ?? false) {
                                      Get.close(1);
                                    }
                                    Navigator.of(context).pop();
                                    Future.delayed(Duration(milliseconds: 400), ()
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
                                                SizedBox(height: 10.0),
                                                Obx(() => LinearProgressIndicator(
                                                  backgroundColor: context.theme.colorScheme.outline,
                                                  value: progress.value,
                                                  minHeight: 5,
                                                  valueColor:
                                                  AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                                ),
                                                ),
                                                SizedBox(
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
                                  for (Contact c in ContactManager().contacts) {
                                    var map = c.toMap();
                                    contacts.add(map);
                                  }
                                  api.createContact(contacts, onSendProgress: (count, total) {
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
                                              final dir = Directory("${SettingsManager().appDocDir.path}/attachments");
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
                                            await DBProvider.deleteDB();
                                            await SettingsManager().resetConnection();
                                            SettingsManager().settings = Settings();
                                            SettingsManager().settings.save();
                                            SettingsManager().fcmData = null;
                                            FCMData.deleteFcmData();
                                            prefs.setString("selected-dark", "OLED Dark");
                                            prefs.setString("selected-light", "Bright White");
                                            themeBox.putMany(Themes.defaultThemes);
                                            loadTheme(context);
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
                                CustomNavigator.pushAndRemoveSettingsUntil(
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
            CustomNavigator.maxWidthSettings = constraints.maxWidth;
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
                          backgroundColor: SettingsManager().settings.skin.value != Skins.iOS ? tileColor : headerColor,
                          body: Center(
                            child: Text("Select a settings page from the list",
                                style: context.theme.textTheme.bodyLarge),
                          ))),
                ],
              ),
            );
          }),
        )
      ),
    );
  }
}
