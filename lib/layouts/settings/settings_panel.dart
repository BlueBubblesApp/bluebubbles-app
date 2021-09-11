import 'dart:convert';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:ui';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/settings/about_panel.dart';
import 'package:bluebubbles/layouts/settings/attachment_panel.dart';
import 'package:bluebubbles/layouts/settings/chat_list_panel.dart';
import 'package:bluebubbles/layouts/settings/conversation_panel.dart';
import 'package:bluebubbles/layouts/settings/notification_panel.dart';
import 'package:bluebubbles/layouts/settings/private_api_panel.dart';
import 'package:bluebubbles/layouts/settings/redacted_mode_panel.dart';
import 'package:bluebubbles/layouts/settings/server_management_panel.dart';
import 'package:bluebubbles/layouts/settings/theme_panel.dart';
import 'package:bluebubbles/layouts/settings/troubleshoot_panel.dart';
import 'package:bluebubbles/layouts/widgets/vertical_split_view.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/theme_entry.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/settings/misc_panel.dart';
import 'package:bluebubbles/layouts/widgets/CustomCupertinoTextField.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

List disconnectedStates = [SocketState.DISCONNECTED, SocketState.ERROR, SocketState.FAILED];

class SettingsPanel extends StatefulWidget {
  SettingsPanel({Key? key}) : super(key: key);

  @override
  _SettingsPanelState createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late Settings _settingsCopy;
  bool needToReconnect = false;
  int? lastRestart;

  @override
  void initState() {
    super.initState();
    _settingsCopy = SettingsManager().settings;
  }

  @override
  Widget build(BuildContext context) {
    Color headerColor;
    if (Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).accentColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: headerColor, // navigation bar color
        systemNavigationBarIconBrightness: headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: buildForDevice(),
    );
  }

  Widget buildSettingsList() {
    Widget nextIcon = Obx(() => Icon(
          SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.chevron_right : Icons.arrow_forward,
          color: Colors.grey,
        ));

    final iosSubtitle =
        Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context)
        .textTheme
        .subtitle1
        ?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if (Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }
    return Obx(() => Scaffold(
          backgroundColor: SettingsManager().settings.skin.value != Skins.iOS ? tileColor : headerColor,
          appBar: PreferredSize(
            preferredSize: Size(CustomNavigator.width(context), 80),
            child: ClipRRect(
              child: BackdropFilter(
                child: AppBar(
                  brightness: ThemeData.estimateBrightnessForColor(headerColor),
                  toolbarHeight: 100.0,
                  elevation: 0,
                  leading: buildBackButton(context),
                  backgroundColor: headerColor.withOpacity(0.5),
                  title: Text(
                    "Settings",
                    style: Theme.of(context).textTheme.headline1,
                  ),
                ),
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              ),
            ),
          ),
          body: CustomScrollView(
            physics: ThemeSwitcher.getScrollPhysics(),
            slivers: <Widget>[
              SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    Container(
                        height: SettingsManager().settings.skin.value == Skins.iOS ? 30 : 40,
                        alignment: Alignment.bottomLeft,
                        decoration: SettingsManager().settings.skin.value == Skins.iOS
                            ? BoxDecoration(
                                color: headerColor,
                                border: Border(
                                    bottom: BorderSide(
                                        color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                              )
                            : BoxDecoration(
                                color: tileColor,
                              ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, left: 15),
                          child: Text("Server Management".psCapitalize,
                              style:
                                  SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                        )),
                    Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
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
                            binding: ServerManagementPanelBinding(),
                          );
                        },
                        onLongPress: () {
                          Clipboard.setData(new ClipboardData(text: _settingsCopy.serverAddress.value));
                          showSnackbar('Copied', "Address copied to clipboard");
                        },
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
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
                                      SettingsManager().settings.skin.value == Skins.iOS ? Colors.white : Colors.grey,
                                  size: SettingsManager().settings.skin.value == Skins.iOS ? 23 : 30,
                                ),
                                if (SettingsManager().settings.skin.value != Skins.iOS)
                                  Positioned.fill(
                                    child: Align(
                                        alignment: Alignment.bottomRight,
                                        child:
                                            getIndicatorIcon(SocketManager().state.value, size: 15, showAlpha: false)),
                                  ),
                              ]),
                            ),
                          ],
                        ),
                        trailing: nextIcon,
                      );
                    }),
                    SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Appearance"),
                    SettingsTile(
                      backgroundColor: tileColor,
                      title: "Theme Settings",
                      subtitle: SettingsManager().settings.skin.value.toString().split(".").last +
                          "   |   " +
                          AdaptiveTheme.of(context).mode.toString().split(".").last.capitalizeFirst! +
                          " Mode",
                      onTap: () {
                        CustomNavigator.pushAndRemoveSettingsUntil(
                          context,
                          ThemePanel(),
                          (route) => route.isFirst,
                          binding: ThemePanelBinding(),
                        );
                      },
                      trailing: nextIcon,
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.paintbrush,
                        materialIcon: Icons.palette,
                      ),
                    ),
                    SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Application Settings"),
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
                        child: SettingsDivider(color: headerColor),
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
                        child: SettingsDivider(color: headerColor),
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
                        child: SettingsDivider(color: headerColor),
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
                        child: SettingsDivider(color: headerColor),
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
                    SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Advanced"),
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
                          binding: PrivateAPIPanelBinding(),
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
                        child: SettingsDivider(color: headerColor),
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
                    // SettingsTile(
                    //   title: "Message Scheduling",
                    //   trailing: Icon(Icons.arrow_forward_ios,
                    //       color: Theme.of(context).primaryColor),
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
                    //       color: Theme.of(context).primaryColor),
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
                    SettingsHeader(
                        headerColor: headerColor,
                        tileColor: tileColor,
                        iosSubtitle: iosSubtitle,
                        materialSubtitle: materialSubtitle,
                        text: "Backup and Reset"),
                    SettingsTile(
                      backgroundColor: tileColor,
                      onTap: () {
                        Get.defaultDialog(
                          title: "Backup and Restore",
                          titleStyle: Theme.of(context).textTheme.headline1,
                          confirm: Container(height: 0, width: 0),
                          cancel: Container(height: 0, width: 0),
                          content: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                            SizedBox(
                              height: 15.0,
                            ),
                            Text("Load / Save Locally", style: Theme.of(context).textTheme.subtitle1),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              child: Container(color: Colors.grey, height: 0.5),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    primary: Theme.of(context).primaryColor,
                                  ),
                                  onPressed: () async {
                                    String directoryPath = "/storage/emulated/0/Download/BlueBubbles-settings-";
                                    DateTime now = DateTime.now().toLocal();
                                    String filePath = directoryPath +
                                        "${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}" +
                                        ".json";
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
                                    File file = File(filePath);
                                    await file.create(recursive: true);
                                    String jsonString = jsonEncode(json);
                                    await file.writeAsString(jsonString);
                                    Get.back();
                                    showSnackbar(
                                      "Success",
                                      "Settings exported successfully to downloads folder",
                                      durationMs: 2000,
                                      button: TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor: Get.theme.accentColor,
                                        ),
                                        onPressed: () {
                                          Share.file("BlueBubbles Settings", filePath);
                                        },
                                        child: Text("SHARE", style: TextStyle(color: Theme.of(context).primaryColor)),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Save Settings",
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyText1!.color,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(color: Theme.of(context).primaryColor)),
                                    primary: Theme.of(context).backgroundColor,
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
                                    } catch (e, s) {
                                      print(e);
                                      print(s);
                                      Get.back();
                                      showSnackbar("Error", "Something went wrong");
                                    }
                                  },
                                  child: Text(
                                    "Load Settings",
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyText1!.color,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    primary: Theme.of(context).primaryColor,
                                  ),
                                  onPressed: () async {
                                    List<ThemeObject> allThemes = await ThemeObject.getThemes();
                                    String jsonStr = "[";
                                    allThemes.forEachIndexed((index, e) async {
                                      String entryJson = "[";
                                      await e.fetchData();
                                      e.entries.forEachIndexed((index, e2) {
                                        entryJson = entryJson + "${jsonEncode(e2.toMap())}";
                                        if (index != e.entries.length - 1) {
                                          entryJson = entryJson + ",";
                                        } else {
                                          entryJson = entryJson + "]";
                                        }
                                      });
                                      Map<String, dynamic> map = e.toMap();
                                      Logger.debug(entryJson);
                                      map['entries'] = jsonDecode(entryJson);
                                      jsonStr = jsonStr + "${jsonEncode(map)}";
                                      if (index != allThemes.length - 1) {
                                        jsonStr = jsonStr + ",";
                                      } else {
                                        jsonStr = jsonStr + "]";
                                      }
                                    });
                                    String directoryPath = "/storage/emulated/0/Download/BlueBubbles-theming-";
                                    DateTime now = DateTime.now().toLocal();
                                    String filePath = directoryPath +
                                        "${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}" +
                                        ".json";
                                    if (kIsWeb) {
                                      final bytes = utf8.encode(jsonStr);
                                      final content = base64.encode(bytes);
                                      html.AnchorElement(
                                          href: "data:application/octet-stream;charset=utf-16le;base64,$content")
                                        ..setAttribute("download", filePath.split("/").last)
                                        ..click();
                                      return;
                                    }
                                    File file = File(filePath);
                                    await file.create(recursive: true);
                                    await file.writeAsString(jsonStr);
                                    Get.back();
                                    showSnackbar(
                                      "Success",
                                      "Theming exported successfully to downloads folder",
                                      durationMs: 2000,
                                      button: TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor: Get.theme.accentColor,
                                        ),
                                        onPressed: () {
                                          Share.file("BlueBubbles Theming", filePath);
                                        },
                                        child: Text("SHARE", style: TextStyle(color: Theme.of(context).primaryColor)),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "Save Theming",
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyText1!.color,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(color: Theme.of(context).primaryColor)),
                                    primary: Theme.of(context).backgroundColor,
                                  ),
                                  onPressed: () async {
                                    final res = await FilePicker.platform
                                        .pickFiles(withData: true, type: FileType.custom, allowedExtensions: ["json"]);
                                    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;

                                    try {
                                      String jsonString = Utf8Decoder().convert(res.files.first.bytes!);
                                      List<dynamic> json = jsonDecode(jsonString);
                                      for (var e in json) {
                                        ThemeObject object = ThemeObject.fromMap(e);
                                        List<dynamic> entriesJson = e['entries'];
                                        List<ThemeEntry> entries = [];
                                        for (var e2 in entriesJson) {
                                          entries.add(ThemeEntry.fromMap(e2));
                                        }
                                        object.entries = entries;
                                        object.data = object.themeData;
                                        await object.save();
                                      }
                                      await SettingsManager().saveSelectedTheme(context);
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
                                      color: Theme.of(context).textTheme.bodyText1!.color,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ]),
                          barrierDismissible: true,
                          backgroundColor: Theme.of(context).backgroundColor,
                        );
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
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                    if (!kIsWeb && !kIsDesktop)
                      SettingsTile(
                        backgroundColor: tileColor,
                        onTap: () async {
                          String json = "[";
                          await ContactManager().getAvatars();
                          ContactManager().handleToContact.values.forEachIndexed((index, c) {
                            if (c == null) return;
                            json = json + "${jsonEncode(c.toMap())}";
                            if (index != ContactManager().handleToContact.values.length - 1) {
                              json = json + ",";
                            } else {
                              json = json + "]";
                            }
                          });
                          SocketManager().sendMessage("save-vcf", {"vcf": json}, (_) => showSnackbar("Notice", "Successfully exported contacts to server"));
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
                          child: SettingsDivider(color: headerColor),
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
                                style: Theme.of(context).textTheme.bodyText1,
                              ),
                              backgroundColor: Theme.of(context).backgroundColor,
                              actions: <Widget>[
                                TextButton(
                                  child: Text("Yes"),
                                  onPressed: () async {
                                    await DBProvider.deleteDB();
                                    await SettingsManager().resetConnection();
                                    SettingsManager().settings.finishedSetup.value = false;
                                    SocketManager().finishedSetup.sink.add(false);
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                  },
                                ),
                                TextButton(
                                  child: Text("Cancel"),
                                  onPressed: () {
                                    Navigator.of(context).pop();
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
                      title: "Reset",
                      subtitle: "Resets the app to default settings",
                    ),
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
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
                    Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                    Container(
                      height: 30,
                      decoration: SettingsManager().settings.skin.value == Skins.iOS
                          ? BoxDecoration(
                              color: headerColor,
                              border: Border(
                                  top: BorderSide(
                                      color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[],
                ),
              )
            ],
          ),
        ));
  }

  Widget buildForLandscape(BuildContext context, Widget settingsList) {
    Color headerColor;
    Color tileColor;
    if (Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }
    return VerticalSplitView(
      dividerWidth: 10.0,
      initialRatio: 0.4,
      minRatio: 0.33,
      maxRatio: 0.5,
      allowResize: true,
      left: settingsList,
      right: LayoutBuilder(builder: (context, constraints) {
        CustomNavigator.maxWidthSettings = constraints.maxWidth;
        return WillPopScope(
          onWillPop: () async {
            Get.back(id: 3);
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
                                style: Theme.of(Get.context!).textTheme.subtitle1!.copyWith(fontSize: 18))),
                      ))),
            ],
          ),
        );
      }),
    );
  }

  Widget buildForDevice() {
    bool showAltLayout = !context.isPhone || context.isLandscape;
    Widget settingsList = buildSettingsList();
    if (showAltLayout) {
      return buildForLandscape(context, settingsList);
    }

    return settingsList;
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

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    Key? key,
    this.onTap,
    this.onLongPress,
    this.title,
    this.trailing,
    this.leading,
    this.subtitle,
    this.backgroundColor,
    this.isThreeLine = false,
  }) : super(key: key);

  final Function? onTap;
  final Function? onLongPress;
  final String? subtitle;
  final String? title;
  final Widget? trailing;
  final Widget? leading;
  final Color? backgroundColor;
  final bool isThreeLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: ListTile(
        onLongPress: this.onLongPress as void Function()?,
        tileColor: backgroundColor,
        onTap: this.onTap as void Function()?,
        leading: leading,
        title: Text(
          this.title!,
          style: Theme.of(context).textTheme.bodyText1,
        ),
        trailing: this.trailing,
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: Theme.of(context).textTheme.subtitle1,
              )
            : null,
        isThreeLine: isThreeLine,
      ),
    );
  }
}

class SettingsTextField extends StatelessWidget {
  const SettingsTextField(
      {Key? key,
      this.onTap,
      required this.title,
      this.trailing,
      required this.controller,
      this.placeholder,
      this.maxLines = 14,
      this.keyboardType = TextInputType.multiline,
      this.inputFormatters = const []})
      : super(key: key);

  final TextEditingController controller;
  final Function? onTap;
  final String title;
  final String? placeholder;
  final Widget? trailing;
  final int maxLines;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).backgroundColor,
      child: InkWell(
        onTap: this.onTap as void Function()?,
        child: Column(
          children: <Widget>[
            ListTile(
              title: Text(
                this.title,
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: this.trailing,
              subtitle: Padding(
                padding: EdgeInsets.only(top: 10.0),
                child: CustomCupertinoTextField(
                  cursorColor: Theme.of(context).primaryColor,
                  onLongPressStart: () {
                    Feedback.forLongPress(context);
                  },
                  onTap: () {
                    HapticFeedback.selectionClick();
                  },
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: inputFormatters,
                  autocorrect: true,
                  controller: controller,
                  scrollPhysics: CustomBouncingScrollPhysics(),
                  style: Theme.of(context).textTheme.bodyText1!.apply(
                      color: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.light
                          ? Colors.black
                          : Colors.white,
                      fontSizeDelta: -0.25),
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  minLines: 1,
                  placeholder: placeholder ?? "Enter your text here",
                  padding: EdgeInsets.only(left: 10, top: 10, right: 40, bottom: 10),
                  placeholderStyle: Theme.of(context).textTheme.subtitle1,
                  autofocus: SettingsManager().settings.autoOpenKeyboard.value,
                  decoration: BoxDecoration(
                    color: Theme.of(context).backgroundColor,
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            Divider(
              color: Theme.of(context).accentColor.withOpacity(0.5),
              thickness: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsSwitch extends StatelessWidget {
  SettingsSwitch({
    Key? key,
    required this.initialVal,
    required this.onChanged,
    required this.title,
    this.backgroundColor,
    this.subtitle,
  }) : super(key: key);
  final bool initialVal;
  final Function(bool) onChanged;
  final String title;
  final Color? backgroundColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: SwitchListTile(
        tileColor: backgroundColor,
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyText1,
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: Theme.of(context).textTheme.subtitle1,
              )
            : null,
        value: initialVal,
        activeColor: Theme.of(context).primaryColor,
        activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
        inactiveTrackColor: backgroundColor == Theme.of(context).accentColor
            ? Theme.of(context).backgroundColor.withOpacity(0.6)
            : Theme.of(context).accentColor.withOpacity(0.6),
        inactiveThumbColor: backgroundColor == Theme.of(context).accentColor
            ? Theme.of(context).backgroundColor
            : Theme.of(context).accentColor,
        onChanged: onChanged,
      ),
    );
  }
}

class SettingsOptions<T extends Object> extends StatelessWidget {
  SettingsOptions({
    Key? key,
    required this.onChanged,
    required this.options,
    this.cupertinoCustomWidgets,
    required this.initial,
    this.textProcessing,
    required this.title,
    this.subtitle,
    this.capitalize = true,
    this.backgroundColor,
    this.secondaryColor,
  }) : super(key: key);
  final String title;
  final void Function(T?) onChanged;
  final List<T> options;
  final Iterable<Widget>? cupertinoCustomWidgets;
  final T initial;
  final String Function(T)? textProcessing;
  final String? subtitle;
  final bool capitalize;
  final Color? backgroundColor;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    if (SettingsManager().settings.skin.value == Skins.iOS) {
      final texts = options.map((e) => Text(capitalize ? textProcessing!(e).capitalize! : textProcessing!(e)));
      final map = Map<T, Widget>.fromIterables(options, cupertinoCustomWidgets ?? texts);
      return Container(
        color: backgroundColor,
        padding: EdgeInsets.symmetric(horizontal: 13),
        height: 50,
        child: CupertinoSlidingSegmentedControl<T>(
          children: map,
          groupValue: initial,
          thumbColor: secondaryColor != null && secondaryColor == backgroundColor
              ? secondaryColor!.lightenOrDarken(20)
              : secondaryColor ?? Colors.white,
          backgroundColor: backgroundColor ?? CupertinoColors.tertiarySystemFill,
          onValueChanged: onChanged,
        ),
      );
    }
    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                  ),
                  (subtitle != null)
                      ? Container(
                          constraints: BoxConstraints(maxWidth: CustomNavigator.width(context) * 2 / 3),
                          child: Padding(
                            padding: EdgeInsets.only(top: 3.0),
                            child: Text(
                              subtitle ?? "",
                              style: Theme.of(context).textTheme.subtitle1,
                            ),
                          ),
                        )
                      : Container(),
                ]),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).accentColor,
              ),
              child: Center(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    dropdownColor: Theme.of(context).accentColor,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).textTheme.bodyText1!.color,
                    ),
                    value: initial,
                    items: options.map<DropdownMenuItem<T>>((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(
                          capitalize ? textProcessing!(e).capitalize! : textProcessing!(e),
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                      );
                    }).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsSlider extends StatelessWidget {
  SettingsSlider(
      {required this.startingVal,
      this.update,
      required this.text,
      this.formatValue,
      required this.min,
      required this.max,
      required this.divisions,
      this.leading,
      this.backgroundColor,
      Key? key})
      : super(key: key);

  final double startingVal;
  final Function(double val)? update;
  final String text;
  final Function(double value)? formatValue;
  final double min;
  final double max;
  final int divisions;
  final Widget? leading;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    String value = startingVal.toString();
    if (formatValue != null) {
      value = formatValue!(startingVal);
    }

    return Container(
      color: backgroundColor,
      child: ListTile(
        tileColor: backgroundColor,
        leading: leading,
        trailing: Text(value),
        title: SettingsManager().settings.skin.value == Skins.iOS
            ? CupertinoSlider(
                activeColor: Theme.of(context).primaryColor,
                value: startingVal,
                onChanged: update,
                divisions: divisions,
                min: min,
                max: max,
              )
            : Slider(
                activeColor: Theme.of(context).primaryColor,
                inactiveColor: Theme.of(context).primaryColor.withOpacity(0.2),
                value: startingVal,
                onChanged: update,
                label: value,
                divisions: divisions,
                min: min,
                max: max,
              ),
      ),
    );
  }
}

class SettingsHeader extends StatelessWidget {
  final Color headerColor;
  final Color tileColor;
  final TextStyle? iosSubtitle;
  final TextStyle? materialSubtitle;
  final String text;

  SettingsHeader(
      {required this.headerColor,
      required this.tileColor,
      required this.iosSubtitle,
      required this.materialSubtitle,
      required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
      Container(
          height: SettingsManager().settings.skin.value == Skins.iOS ? 60 : 40,
          alignment: Alignment.bottomLeft,
          decoration: SettingsManager().settings.skin.value == Skins.iOS
              ? BoxDecoration(
                  color: headerColor,
                  border: Border.symmetric(
                      horizontal: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                )
              : BoxDecoration(
                  color: tileColor,
                  border:
                      Border(top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)),
                ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 15),
            child: Text(text.psCapitalize,
                style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
          )),
      Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
    ]);
  }
}

class SettingsLeadingIcon extends StatelessWidget {
  final IconData iosIcon;
  final IconData materialIcon;
  final Color? containerColor;

  SettingsLeadingIcon({
    required this.iosIcon,
    required this.materialIcon,
    this.containerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color:
                SettingsManager().settings.skin.value == Skins.iOS ? containerColor ?? Colors.grey : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          alignment: Alignment.center,
          child: Icon(SettingsManager().settings.skin.value == Skins.iOS ? iosIcon : materialIcon,
              color: SettingsManager().settings.skin.value == Skins.iOS ? Colors.white : Colors.grey,
              size: SettingsManager().settings.skin.value == Skins.iOS ? 23 : 30),
        ),
      ],
    );
  }
}

class SettingsDivider extends StatelessWidget {
  final double thickness;
  final Color? color;

  SettingsDivider({
    this.thickness = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (SettingsManager().settings.skin.value != Skins.Material) {
      return Divider(
        color: color ?? Theme.of(context).accentColor.withOpacity(0.5),
        thickness: 1,
      );
    } else {
      return Container();
    }
  }
}
