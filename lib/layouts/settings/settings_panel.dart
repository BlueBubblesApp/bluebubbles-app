import 'dart:convert';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/about_panel.dart';
import 'package:bluebubbles/layouts/settings/attachment_panel.dart';
import 'package:bluebubbles/layouts/settings/chat_list_panel.dart';
import 'package:bluebubbles/layouts/settings/conversation_panel.dart';
import 'package:bluebubbles/layouts/settings/desktop_panel.dart';
import 'package:bluebubbles/layouts/settings/misc_panel.dart';
import 'package:bluebubbles/layouts/settings/notification_panel.dart';
import 'package:bluebubbles/layouts/settings/private_api_panel.dart';
import 'package:bluebubbles/layouts/settings/redacted_mode_panel.dart';
import 'package:bluebubbles/layouts/settings/server_management_panel.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/layouts/settings/theme_panel.dart';
import 'package:bluebubbles/layouts/settings/troubleshoot_panel.dart';
import 'package:bluebubbles/layouts/setup/setup_view.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/vertical_split_view.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/intents.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:bluebubbles/main.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

List disconnectedStates = [SocketState.DISCONNECTED, SocketState.ERROR, SocketState.FAILED];

class SettingsPanel extends StatefulWidget {
  SettingsPanel({Key? key}) : super(key: key);

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late Settings _settingsCopy;
  bool needToReconnect = false;
  bool pushedServerManagement = false;
  int? lastRestart;
  final ScrollController scrollController = ScrollController();
  final RxBool uploadingContacts = false.obs;
  final RxnDouble progress = RxnDouble();
  final RxnInt totalSize = RxnInt();

  @override
  void initState() {
    super.initState();
    _settingsCopy = SettingsManager().settings;

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'theme-update' && mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration.zero, () {
      if (!pushedServerManagement && SettingsManager().settings.tabletMode.value && (!context.isPhone || context.isLandscape)) {
        pushedServerManagement = true;
        CustomNavigator.pushAndRemoveSettingsUntil(
          context,
          ServerManagementPanel(),
              (route) => route.isFirst,
        );
      }
    });
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
        child: Obx(() => buildForDevice())
      ),
    );
  }

  Widget buildSettingsList() {
    Widget nextIcon = Obx(() => SettingsManager().settings.skin.value != Skins.Material ? Icon(
          SettingsManager().settings.skin.value != Skins.Material ? CupertinoIcons.chevron_right : Icons.arrow_forward,
          color: context.theme.colorScheme.outline,
          size: SettingsManager().settings.skin.value == Skins.iOS ? 18 : 24,
        ) : SizedBox.shrink());

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

    return Obx(() => SettingsScaffold(
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
                            Clipboard.setData(ClipboardData(text: _settingsCopy.serverAddress.value));
                            showSnackbar('Copied', "Address copied to clipboard");
                          },
                          leading: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Material(
                                shape: SettingsManager().settings.skin.value == Skins.Samsung ? SquircleBorder(
                                  side: BorderSide(color: SettingsManager().settings.skin.value == Skins.Samsung ? getIndicatorColor(SocketManager().state.value) : Colors.transparent, width: 3.0),
                                ) : null,
                                color: SettingsManager().settings.skin.value == Skins.Samsung ? getIndicatorColor(SocketManager().state.value) : Colors.transparent,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: SettingsManager().settings.skin.value == Skins.iOS
                                        ? getIndicatorColor(SocketManager().state.value)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  alignment: Alignment.center,
                                  child: Stack(children: [
                                    Icon(
                                      SettingsManager().settings.skin.value == Skins.iOS
                                          ? CupertinoIcons.antenna_radiowaves_left_right
                                          : Icons.router,
                                      color:
                                      SettingsManager().settings.skin.value != Skins.Material ? Colors.white : Colors.grey,
                                      size: SettingsManager().settings.skin.value != Skins.Material ? 23 : 30,
                                    ),
                                    if (SettingsManager().settings.skin.value == Skins.Material)
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
                            ThemePanel(),
                                (route) => route.isFirst,
                          );
                        },
                        trailing: nextIcon,
                        leading: SettingsLeadingIcon(
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
                        leading: SettingsLeadingIcon(
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
                        leading: SettingsLeadingIcon(
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
                        leading: SettingsLeadingIcon(
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
                        leading: SettingsLeadingIcon(
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
                          leading: SettingsLeadingIcon(
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
                        leading: SettingsLeadingIcon(
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
                        leading: SettingsLeadingIcon(
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
                            showBackupDialog(context);
                          },
                          leading: SettingsLeadingIcon(
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
                            leading: SettingsLeadingIcon(
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
                          leading: SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.floppy_disk,
                            materialIcon: Icons.storage,
                          ),
                          title: kIsWeb ? "Logout" : "Reset",
                          subtitle: kIsWeb ? "" : "Resets the app to default settings",
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
                          leading: SettingsLeadingIcon(
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
        ));
  }

  Widget buildForLandscape(BuildContext context, Widget settingsList) {
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
    return VerticalSplitView(
      initialRatio: 0.4,
      minRatio: kIsDesktop || kIsWeb ? 0.2 : 0.33,
      maxRatio: 0.5,
      allowResize: true,
      left: settingsList,
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
                        child: Container(
                            child: Text("Select a settings page from the list",
                                style: context.theme.textTheme.bodyLarge)),
                      ))),
            ],
          ),
        );
      }),
    );
  }

  void showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.theme.colorScheme.properSurface,
        title: Text("Backup and Restore", style: context.theme.textTheme.titleLarge),
        content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              height: 15.0,
            ),
            Text("Load From / Save To Server", style: context.theme.textTheme.labelLarge),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Container(color: context.theme.textTheme.labelLarge!.color, height: 0.5),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    primary: context.theme.colorScheme.primary,
                    onPrimary: context.theme.colorScheme.onPrimary,
                    onSurface: context.theme.colorScheme.properOnSurface,
                    textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onPrimary),
                  ),
                  onPressed: () async {
                    DateTime now = DateTime.now().toLocal();
                    String name = "Android_${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}-${now.second}";
                    Map<String, dynamic> json = SettingsManager().settings.toMap();
                    var response = await api.setSettings(name, json);
                    if (response.statusCode != 200) {
                      Get.back();
                      showSnackbar(
                        "Error",
                        "Somthing went wrong",
                      );
                    } else {
                      Get.back();
                      showSnackbar(
                        "Success",
                        "Settings exported successfully to server",
                      );
                    }
                  },
                  child: Text(
                    "Save Settings",
                    style: TextStyle(
                      color: context.theme.colorScheme.onPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: context.theme.colorScheme.primary)),
                    primary: context.theme.colorScheme.properSurface,
                    onPrimary: context.theme.colorScheme.onPrimary,
                    onSurface: context.theme.colorScheme.properOnSurface,
                    textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                  ),
                  onPressed: () async {
                    var response = await api.getSettings();
                    if (response.statusCode == 200 && response.data.isNotEmpty) {
                      try {
                        List<dynamic> json = response.data['data'];
                        Get.back();
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("Settings Backups", style: context.theme.textTheme.titleLarge),
                            backgroundColor: context.theme.colorScheme.properSurface,
                            content: Container(
                              constraints: BoxConstraints(
                                maxHeight: 300,
                              ),
                              child: Container(
                                width: 300,
                                height: 300,
                                constraints: BoxConstraints(
                                  maxHeight: Get.height - 300,
                                ),
                                child: StatefulBuilder(
                                    builder: (context, setState) {
                                      return SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text("Select the backup you would like to restore", style: context.theme.textTheme.bodyLarge),
                                            ),
                                            ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: json.length,
                                              physics: NeverScrollableScrollPhysics(),
                                              itemBuilder: (context, index) {
                                                String finalName = "";
                                                if(json[index]['name'].toString().contains("-")){
                                                  String date = json[index]['name'].toString().split("_")[1];
                                                  String time = json[index]['name'].toString().split("_")[2];
                                                  String year = date.split("-")[0];
                                                  String month = date.split("-")[1];
                                                  String day = date.split("-")[2];
                                                  String hour = time.split("-")[0];
                                                  String min = time.split("-")[1];
                                                  String sec = time.split("-")[2];
                                                  String timeType = "";
                                                  if(!SettingsManager().settings.use24HrFormat.value){
                                                    if(int.parse(hour) >= 12 && int.parse(hour) < 24){
                                                      timeType = "PM";
                                                    } else{
                                                      timeType = "AM";
                                                    }
                                                  }
                                                  if(int.parse(min) < 10){
                                                    min = "0$min";
                                                  }
                                                  if(int.parse(sec) < 10){
                                                    sec = "0$sec";
                                                  }
                                                  if(int.parse(hour) > 12 && !SettingsManager().settings.use24HrFormat.value){
                                                    hour = (int.parse(hour) -12).toString();
                                                  }
                                                  finalName = "$month/$day/$year at $hour:$min:$sec $timeType";
                                                } else{
                                                  finalName = json[index]['name'].toString();
                                                }
                                                return ListTile(
                                                  title: Text(finalName, style: context.theme.textTheme.bodyLarge),
                                                  onTap: () {
                                                    Settings.updateFromMap(json[index]);
                                                    Navigator.of(context).pop();
                                                    showSnackbar("Success", "Settings restored successfully");
                                                  },
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                ),
                              ),
                            ),
                          )
                        );
                      } catch (_) {
                        Get.back();
                        showSnackbar("Error", "Something went wrong");
                      }
                    } else {
                      Get.back();
                      showSnackbar("Error", "Something went wrong");
                    }
                  },
                  child: Text(
                    "Load Settings",
                    style: TextStyle(
                      color: context.theme.textTheme.bodyMedium!.color,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (!kIsWeb)
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        primary: context.theme.colorScheme.primary,
                        onPrimary: context.theme.colorScheme.onPrimary,
                        onSurface: context.theme.colorScheme.properOnSurface,
                        textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onPrimary),
                      ),
                      onPressed: () async {
                        List<ThemeStruct> allThemes = ThemeStruct.getThemes().where((element) => !element.isPreset).toList();
                        bool errored = false;
                        for (ThemeStruct e in allThemes) {
                          String name = "BlueBubbles Custom Theme - ${e.name}";
                          var response = await api.setTheme(name, e.toMap());
                          if (response.statusCode != 200) {
                            errored = true;
                          }
                        }
                        Get.back();
                        if (allThemes.isEmpty) {
                          showSnackbar(
                            "Notice",
                            "No custom themes found!",
                          );
                        } else if (errored) {
                          showSnackbar(
                            "Error",
                            "Somthing went wrong",
                          );
                        } else {
                          showSnackbar(
                            "Success",
                            "Themes exported successfully to server",
                          );
                        }
                      },
                      child: Text(
                        "Save Theming",
                        style: TextStyle(
                          color: context.theme.colorScheme.onPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: context.theme.colorScheme.primary)),
                        primary: context.theme.colorScheme.properSurface,
                        onPrimary: context.theme.colorScheme.onPrimary,
                        onSurface: context.theme.colorScheme.properOnSurface,
                        textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                      ),
                      onPressed: () async {
                        var response = await api.getTheme();
                        if (response.statusCode == 200 && response.data.isNotEmpty) {
                          try {
                            List<dynamic> json = response.data['data'];
                            Get.back();
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text("Theme Backups", style: context.theme.textTheme.titleLarge),
                                backgroundColor: context.theme.colorScheme.properSurface,
                                content: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: 300,
                                  ),
                                  child: Container(
                                    width: 300,
                                    height: 300,
                                    constraints: BoxConstraints(
                                      maxHeight: Get.height - 300,
                                    ),
                                    child: StatefulBuilder(
                                        builder: (context, setState) {
                                          return SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: Text("Select the theme you would like to restore", style: context.theme.textTheme.bodyLarge),
                                                ),
                                                ListView.builder(
                                                  shrinkWrap: true,
                                                  itemCount: json.length,
                                                  physics: NeverScrollableScrollPhysics(),
                                                  itemBuilder: (context, index) {
                                                    return ListTile(
                                                      title: Text(json[index]['name'], style: context.theme.textTheme.bodyLarge),
                                                      onTap: () async {
                                                        ThemeStruct object = ThemeStruct.fromMap(json[index]);
                                                        object.id = null;
                                                        object.save();
                                                        Navigator.of(context).pop();
                                                        showSnackbar("Success", "Theme restored successfully");
                                                      },
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                    ),
                                  ),
                                ),
                              )
                            );
                          } catch (_) {
                            Get.back();
                            showSnackbar("Error", "Something went wrong");
                          }
                        } else {
                          Get.back();
                          showSnackbar("Error", "Something went wrong");
                        }
                      },
                      child: Text(
                        "Load Theming",
                        style: TextStyle(
                          color: context.theme.textTheme.bodyMedium!.color,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ]
              ),
            SizedBox(
              height: 15.0,
            ),
            Text("Load / Save Locally", style: context.theme.textTheme.labelLarge),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Container(color: context.theme.textTheme.labelLarge!.color, height: 0.5),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    primary: context.theme.colorScheme.primary,
                    onPrimary: context.theme.colorScheme.onPrimary,
                    onSurface: context.theme.colorScheme.properOnSurface,
                    textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onPrimary),
                  ),
                  onPressed: () async {
                    String directoryPath = "/storage/emulated/0/Download/BlueBubbles-settings-";
                    DateTime now = DateTime.now().toLocal();
                    String filePath = "$directoryPath${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.json";
                    Map<String, dynamic> json = SettingsManager().settings.toMap();
                    if (kIsWeb) {
                      final bytes = utf8.encode(jsonEncode(json));
                      final content = base64.encode(bytes);
                      html.AnchorElement(
                          href: "data:application/octet-stream;charset=utf-16le;base64,$content")
                        ..setAttribute("download", filePath.split("/").last)
                        ..click();
                      return;
                    }
                    if (kIsDesktop) {
                      String? _filePath = await FilePicker.platform.saveFile(
                        initialDirectory: (await getDownloadsDirectory())?.path,
                        dialogTitle: 'Choose a location to save this file',
                        fileName: "BlueBubbles-settings-${now.year}${now.month}${now.day}_${now
                            .hour}${now.minute}${now.second}.json",
                      );
                      if (_filePath == null) {
                        return showSnackbar('Failed', 'You didn\'t select a file path!');
                      }
                      filePath = _filePath;
                    }
                    File file = File(filePath);
                    await file.create(recursive: true);
                    String jsonString = jsonEncode(json);
                    await file.writeAsString(jsonString);
                    Get.back();
                    showSnackbar(
                      "Success",
                      "Settings exported successfully to ${kIsDesktop ? filePath : "downloads folder"}",
                      durationMs: 2000,
                      button: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Get.theme.colorScheme.secondary,
                        ),
                        onPressed: () {
                          Share.file("BlueBubbles Settings", filePath);
                        },
                        child: kIsDesktop ? SizedBox.shrink() : Text("SHARE", style: TextStyle(color: context.theme.primaryColor)),
                      ),
                    );
                  },
                  child: Text(
                    "Save Settings",
                    style: TextStyle(
                      color: context.theme.colorScheme.onPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: context.theme.colorScheme.primary)),
                    primary: context.theme.colorScheme.properSurface,
                    onPrimary: context.theme.colorScheme.onPrimary,
                    onSurface: context.theme.colorScheme.properOnSurface,
                    textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                  ),
                  onPressed: () async {
                    final res = await FilePicker.platform
                        .pickFiles(withData: true, type: FileType.custom, allowedExtensions: ["json"]);
                    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                    try {
                      String jsonString = Utf8Decoder().convert(res.files.first.bytes!);
                      Map<String, dynamic> json = jsonDecode(jsonString);
                      Settings.updateFromMap(json);
                      Get.back();
                      showSnackbar("Success", "Settings restored successfully");
                    } catch (_) {
                      Get.back();
                      showSnackbar("Error", "Something went wrong");
                    }
                  },
                  child: Text(
                    "Load Settings",
                    style: TextStyle(
                      color: context.theme.textTheme.bodyMedium!.color,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (!kIsWeb)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      primary: context.theme.colorScheme.primary,
                      onPrimary: context.theme.colorScheme.onPrimary,
                      onSurface: context.theme.colorScheme.properOnSurface,
                      textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onPrimary),
                    ),
                    onPressed: () async {
                      List<ThemeStruct> allThemes = ThemeStruct.getThemes().where((element) => !element.isPreset).toList();
                      final List<Map<String, dynamic>> themeData = [];
                      for (ThemeStruct e in allThemes) {
                        themeData.add(e.toMap());
                      }
                      String jsonStr = jsonEncode(themeData);
                      String directoryPath = "/storage/emulated/0/Download/BlueBubbles-theming-";
                      DateTime now = DateTime.now().toLocal();
                      String filePath = "$directoryPath${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.json";
                      if (kIsWeb) {
                        final bytes = utf8.encode(jsonStr);
                        final content = base64.encode(bytes);
                        html.AnchorElement(
                            href: "data:application/octet-stream;charset=utf-16le;base64,$content")
                          ..setAttribute("download", filePath.split("/").last)
                          ..click();
                        return;
                      }
                      if (kIsDesktop) {
                        String? _filePath = await FilePicker.platform.saveFile(
                          initialDirectory: (await getDownloadsDirectory())?.path,
                          dialogTitle: 'Choose a location to save this file',
                          fileName: "BlueBubbles-theming-${now.year}${now.month}${now.day}_${now
                              .hour}${now.minute}${now.second}.json",
                        );
                        if (_filePath == null) {
                          return showSnackbar('Failed', 'You didn\'t select a file path!');
                        }
                        filePath = _filePath;
                      }
                      File file = File(filePath);
                      await file.create(recursive: true);
                      await file.writeAsString(jsonStr);
                      Get.back();
                      showSnackbar(
                        "Success",
                        "Theming exported successfully to ${kIsDesktop ? filePath : "downloads folder"}",
                        durationMs: 2000,
                        button: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Get.theme.colorScheme.secondary,
                          ),
                          onPressed: () {
                            Share.file("BlueBubbles Theming", filePath);
                          },
                          child: kIsDesktop ? SizedBox.shrink() : Text("SHARE", style: TextStyle(color: context.theme.primaryColor)),
                        ),
                      );
                    },
                    child: Text(
                      "Save Theming",
                      style: TextStyle(
                        color: context.theme.colorScheme.onPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: context.theme.colorScheme.primary)),
                      primary: context.theme.colorScheme.properSurface,
                      onPrimary: context.theme.colorScheme.onPrimary,
                      onSurface: context.theme.colorScheme.properOnSurface,
                      textStyle: context.theme.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                    ),
                    onPressed: () async {
                      final res = await FilePicker.platform
                          .pickFiles(withData: true, type: FileType.custom, allowedExtensions: ["json"]);
                      if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                      try {
                        String jsonString = Utf8Decoder().convert(res.files.first.bytes!);
                        List<dynamic> json = jsonDecode(jsonString);
                        for (var e in json) {
                          ThemeStruct object = ThemeStruct.fromMap(e);
                          if (object.isPreset) continue;
                          object.id = null;
                          object.save();
                        }
                        Get.back();
                        showSnackbar("Success", "Theming restored successfully");
                      } catch (_) {
                        Get.back();
                        showSnackbar("Error", "Something went wrong");
                      }
                    },
                    child: Text(
                      "Load Theming",
                      style: TextStyle(
                        color: context.theme.textTheme.bodyMedium!.color,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
          ]
        ),
      )
    );
  }

  Widget buildForDevice() {
    bool showAltLayout = SettingsManager().settings.tabletMode.value && (!context.isPhone || context.isLandscape) && context.width > 600;
    Widget settingsList = buildSettingsList();
    if (showAltLayout) {
      return buildForLandscape(context, settingsList);
    }
    return TitleBarWrapper(child: settingsList);
  }

  void saveSettings() {
    SettingsManager().saveSettings(_settingsCopy);
    if (needToReconnect) {
      SocketManager().startSocketIO(forceNewConnection: true);
    }
  }

  @override
  void dispose() {
    saveSettings();
    super.dispose();
  }
}
