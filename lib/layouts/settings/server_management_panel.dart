import 'dart:async';
import 'dart:convert';
import 'package:bluebubbles/layouts/setup/qr_scan/text_input_url.dart';
import 'package:universal_io/io.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:ui';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/qr_code_scanner.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ServerManagementPanelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ServerManagementPanelController>(() => ServerManagementPanelController());
  }
}

class ServerManagementPanelController extends GetxController {
  final RxnInt latency = RxnInt();
  final RxnString fetchStatus = RxnString();
  final RxnString serverVersion = RxnString();
  final RxnString macOSVersion = RxnString();
  final RxnInt serverVersionCode = RxnInt();
  final RxBool privateAPIStatus = RxBool(false);
  final RxBool helperBundleStatus = RxBool(false);
  final RxnString proxyService = RxnString();

  // Restart trackers
  int? lastRestart;
  int? lastRestartMessages;
  int? lastRestartPrivateAPI;
  final RxBool isRestarting = false.obs;
  final RxBool isRestartingMessages = false.obs;
  final RxBool isRestartingPrivateAPI = false.obs;
  final RxDouble opacity = 1.0.obs;

  late Settings _settingsCopy;
  FCMData? _fcmDataCopy;

  @override
  void onInit() {
    _settingsCopy = SettingsManager().settings;
    _fcmDataCopy = SettingsManager().fcmData;
    if (SocketManager().state.value == SocketState.CONNECTED) {
      int now = DateTime.now().toUtc().millisecondsSinceEpoch;
      SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
        int later = DateTime.now().toUtc().millisecondsSinceEpoch;
        latency.value = later - now;
        macOSVersion.value = res['data']['os_version'];
        serverVersion.value = res['data']['server_version'];
        serverVersionCode.value = serverVersion.value?.split(".").mapIndexed((index, e) {
          if (index == 0) return int.parse(e) * 100;
          if (index == 1) return int.parse(e) * 21;
          return int.parse(e);
        }).sum;
        privateAPIStatus.value = res['data']['private_api'] ?? false;
        helperBundleStatus.value = res['data']['helper_connected'] ?? false;
        proxyService.value = res['data']['proxy_service'];
      });
    }
    super.onInit();
  }

  void saveSettings() async {
    await SettingsManager().saveSettings(_settingsCopy);
  }

  @override
  void dispose() {
    saveSettings();
    super.dispose();
  }
}

class ServerManagementPanel extends GetView<ServerManagementPanelController> {

  @override
  Widget build(BuildContext context) {
    final iosSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Colors.grey, fontWeight: FontWeight.w300);
    final materialSubtitle = Theme.of(context).textTheme.subtitle1?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold);
    Color headerColor;
    Color tileColor;
    if (Theme.of(context).accentColor.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance()
        || SettingsManager().settings.skin.value != Skins.iOS) {
      headerColor = Theme.of(context).accentColor;
      tileColor = Theme.of(context).backgroundColor;
    } else {
      headerColor = Theme.of(context).backgroundColor;
      tileColor = Theme.of(context).accentColor;
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
      tileColor = headerColor;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: headerColor, // navigation bar color
        systemNavigationBarIconBrightness:
        headerColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
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
                  "Connection & Server Management",
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
                      decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                        color: headerColor,
                        border: Border(
                            bottom: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                        ),
                      ) : BoxDecoration(
                        color: tileColor,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 15),
                        child: Text("Connection & Server Details".psCapitalize, style: SettingsManager().settings.skin.value == Skins.iOS ? iosSubtitle : materialSubtitle),
                      )
                  ),
                  Obx(() {
                    bool redact = SettingsManager().settings.redactedMode.value;
                    return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0, left: 15, top: 8.0, right: 15),
                          child: AnimatedOpacity(
                            duration: Duration(milliseconds: 300),
                            opacity: controller.opacity.value,
                            child: SelectableText.rich(
                              TextSpan(
                                  children: [
                                    TextSpan(text: "Connection Status: "),
                                    TextSpan(text: describeEnum(SocketManager().state.value), style: TextStyle(color: getIndicatorColor(SocketManager().state.value))),
                                    TextSpan(text: "\n\n"),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: "Private API Status: "),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: controller.privateAPIStatus.value ? "ENABLED" : "DISABLED", style: TextStyle(color: getIndicatorColor(controller.privateAPIStatus.value
                                          ? SocketState.CONNECTED
                                          : SocketState.DISCONNECTED))),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: "\n\n"),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: "Private API Helper Bundle Status: "),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: controller.helperBundleStatus.value ? "CONNECTED" : "DISCONNECTED", style: TextStyle(color: getIndicatorColor(controller.helperBundleStatus.value
                                          ? SocketState.CONNECTED
                                          : SocketState.DISCONNECTED))),
                                    if ((controller.serverVersionCode.value ?? 0) >= 42)
                                      TextSpan(text: "\n\n"),
                                    TextSpan(text: "Server URL: ${redact ? "Redacted" : controller._settingsCopy.serverAddress}"),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(text: "Latency: ${redact ? "Redacted" : ((controller.latency.value ?? "N/A").toString() + " ms")}"),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(text: "Server Version: ${redact ? "Redacted" : (controller.serverVersion.value ?? "N/A")}"),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(text: "macOS Version: ${redact ? "Redacted" : (controller.macOSVersion.value ?? "N/A")}"),
                                    TextSpan(text: "\n\n"),
                                    TextSpan(text: "Tap to update values...", style: TextStyle(fontStyle: FontStyle.italic)),
                                  ]
                              ),
                              onTap: () {
                                if (SocketManager().state.value != SocketState.CONNECTED) return;
                                controller.opacity.value = 0.0;
                                int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                                SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
                                  int later = DateTime.now().toUtc().millisecondsSinceEpoch;
                                  controller.latency.value = later - now;
                                  controller.macOSVersion.value = res['data']['os_version'];
                                  controller.serverVersion.value = res['data']['server_version'];
                                  controller.privateAPIStatus.value = res['data']['private_api'];
                                  controller.helperBundleStatus.value = res['data']['helper_connected'];
                                  controller.proxyService.value = res['data']['proxy_service'];
                                  controller.opacity.value = 1.0;
                                });
                              },
                            ),
                          ),
                        )
                    );
                  }),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  SettingsTile(
                    title: "Show QR Code",
                    subtitle: "Generate QR Code to screenshot or sync other devices",
                    backgroundColor: tileColor,
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.qrcode,
                      materialIcon: Icons.qr_code,
                    ),
                    onTap: () {
                      /*projectID: result[2],
                      storageBucket: result[3],
                      apiKey: result[4],
                      firebaseURL: result[5],
                      clientID: result[6],
                      applicationID: result[7],*/
                      List<dynamic> json = [
                        SettingsManager().settings.guidAuthKey.value,
                        SettingsManager().settings.serverAddress.value,
                        SettingsManager().fcmData!.projectID,
                        SettingsManager().fcmData!.storageBucket,
                        SettingsManager().fcmData!.apiKey,
                        SettingsManager().fcmData!.firebaseURL,
                        SettingsManager().fcmData!.clientID,
                        SettingsManager().fcmData!.applicationID,
                      ];
                      String qrtext = jsonEncode(json);
                      showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: Container(
                              height: 320,
                              width: 320,
                              child: QrImage(
                                data: qrtext,
                                version: QrVersions.auto,
                                size: 320,
                                gapless: true,
                              ),
                            ),
                            title: Text("QR Code"),
                          )
                      );
                    },
                  ),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Connection & Sync"
                  ),
                  Obx(() {
                    if (controller.proxyService.value != null && SettingsManager().settings.skin.value == Skins.iOS)
                      return Container(
                        decoration: BoxDecoration(
                          color: tileColor,
                        ),
                        padding: EdgeInsets.only(left: 15, top: 5),
                        child: Text("Select Proxy Service"),
                      );
                    else return SizedBox.shrink();
                  }),
                  Obx(() => controller.proxyService.value != null ? SettingsOptions<String>(
                    title: "Proxy Service",
                    options: ["Ngrok", "LocalTunnel", "Dynamic DNS"],
                    initial: controller.proxyService.value!,
                    capitalize: false,
                    textProcessing: (val) => val,
                    onChanged: (val) async {
                      String? url;
                      if (val == "Dynamic DNS") {
                        TextEditingController controller = TextEditingController();
                        await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            actions: [
                              TextButton(
                                child: Text("OK"),
                                onPressed: () async {
                                  if (!controller.text.isURL) {
                                    showSnackbar("Error", "Please enter a valid URL");
                                    return;
                                  }
                                  url = controller.text;
                                  Get.back();
                                },
                              ),
                              TextButton(
                                child: Text("Cancel"),
                                onPressed: () {
                                  Get.back();
                                },
                              )
                            ],
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: "Server Address",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                            title: Text("Enter Server Address"),
                          )
                        );
                        if (url == null) return;
                      }
                      var res = await SocketManager().sendMessage("change-proxy-service", {"service": val}, (_) {});
                      if (res['status'] == 200) {
                        controller.proxyService.value = val;
                        await Future.delayed(Duration(seconds: 2));
                        await SocketManager().refreshConnection();
                        controller.opacity.value = 0.0;
                        int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                        SocketManager().sendMessage("get-server-metadata", {}, (Map<String, dynamic> res) {
                          int later = DateTime.now().toUtc().millisecondsSinceEpoch;
                          controller.latency.value = later - now;
                          controller.macOSVersion.value = res['data']['os_version'];
                          controller.serverVersion.value = res['data']['server_version'];
                          controller.privateAPIStatus.value = res['data']['private_api'];
                          controller.helperBundleStatus.value = res['data']['helper_connected'];
                          controller.proxyService.value = res['data']['proxy_service'];
                          controller.opacity.value = 1.0;
                        });
                      }
                    },
                    backgroundColor: tileColor,
                    secondaryColor: headerColor,
                  ) : SizedBox.shrink()),
                  Obx(() => controller.proxyService.value != null && !kIsWeb ? Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ) : SizedBox.shrink()),
                  if (!kIsWeb && !kIsDesktop)
                    SettingsTile(
                      title: "Re-configure with BlueBubbles Server",
                      subtitle: "Tap to scan QR code   |   Long press for manual entry",
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.gear,
                        materialIcon: Icons.room_preferences,
                      ),
                      backgroundColor: tileColor,
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (connectContext) => TextInputURL(
                            onConnect: () {
                              Get.back();
                              SocketManager().authFCM();
                              SocketManager()
                                  .startSocketIO(forceNewConnection: true);
                            },
                            onClose: () {
                              Get.back();
                            },
                          ),
                        );
                      },
                      onTap: () async {
                        var fcmData;
                        try {
                          fcmData = jsonDecode(
                            await Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (BuildContext context) {
                                  return QRCodeScanner();
                                },
                              ),
                            ),
                          );
                        } catch (e) {
                          return;
                        }
                        if (fcmData != null && fcmData[0] != null && getServerAddress(address: fcmData[1]) != null) {
                          controller._fcmDataCopy = FCMData(
                            projectID: fcmData[2],
                            storageBucket: fcmData[3],
                            apiKey: fcmData[4],
                            firebaseURL: fcmData[5],
                            clientID: fcmData[6],
                            applicationID: fcmData[7],
                          );
                          controller._settingsCopy.guidAuthKey.value = fcmData[0];
                          controller._settingsCopy.serverAddress.value = getServerAddress(address: fcmData[1])!;

                          SettingsManager().saveSettings(controller._settingsCopy);
                          SettingsManager().saveFCMData(controller._fcmDataCopy!);
                          SocketManager().authFCM();
                        }
                      },
                    ),
                  if (!kIsWeb && !kIsDesktop)
                    Container(
                      color: tileColor,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 65.0),
                        child: SettingsDivider(color: headerColor),
                      ),
                    ),
                  if (!kIsWeb)
                    Obx(() {
                      String subtitle;

                      switch (SocketManager().state.value) {
                        case SocketState.CONNECTED:
                          subtitle = "Tap to sync messages";
                          break;
                        default:
                          subtitle = "Disconnected, cannot sync";
                      }

                      return SettingsTile(
                          title: "Manually Sync Messages",
                          subtitle: subtitle,
                          backgroundColor: tileColor,
                          leading: SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.arrow_2_circlepath,
                            materialIcon: Icons.sync,
                          ),
                          onTap: () async {
                            showDialog(
                              context: context,
                              builder: (context) => SyncDialog(),
                            );
                          });
                    }),
                  SettingsHeader(
                      headerColor: headerColor,
                      tileColor: tileColor,
                      iosSubtitle: iosSubtitle,
                      materialSubtitle: materialSubtitle,
                      text: "Server Actions"
                  ),
                  Obx(() => SettingsTile(
                    title: "Fetch & Share Server Logs",
                    subtitle: controller.fetchStatus.value
                        ?? (SocketManager().state.value == SocketState.CONNECTED ? "Tap to fetch logs" : "Disconnected, cannot fetch logs"),
                    backgroundColor: tileColor,
                    leading: SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.doc_plaintext,
                      materialIcon: Icons.article,
                    ),
                    onTap: () {
                      if (![SocketState.CONNECTED].contains(SocketManager().state.value)) return;

                      controller.fetchStatus.value = "Fetching logs, please wait...";

                      SocketManager().sendMessage("get-logs", {"count": 500}, (Map<String, dynamic> res) {
                        if (res['status'] != 200) {
                          controller.fetchStatus.value = "Failed to fetch logs!";

                          return;
                        }

                        if (kIsWeb) {
                          final bytes = utf8.encode(res['data']);
                          final content = base64.encode(bytes);
                          html.AnchorElement(
                              href: "data:application/octet-stream;charset=utf-16le;base64,$content")
                            ..setAttribute("download", "main.log")
                            ..click();
                          return;
                        }

                        String appDocPath = SettingsManager().appDocDir.path;
                        File logFile = new File("$appDocPath/attachments/main.log");

                        if (logFile.existsSync()) {
                          logFile.deleteSync();
                        }

                        logFile.writeAsStringSync(res['data']);

                        try {
                          Share.file("BlueBubbles Server Log", logFile.absolute.path);
                          controller.fetchStatus.value = null;
                        } catch (ex) {
                          controller.fetchStatus.value = "Failed to share file! ${ex.toString()}";
                        }
                      });
                    },
                  )),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Obx(() => SettingsTile(
                      title: "Restart iMessage",
                      subtitle: controller.isRestartingMessages.value && SocketManager().state.value == SocketState.CONNECTED
                          ? "Restart in progress..." : SocketManager().state.value == SocketState.CONNECTED ? "Restart the iMessage app" : "Disconnected, cannot restart",
                      backgroundColor: tileColor,
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.chat_bubble,
                        materialIcon: Icons.sms,
                      ),
                      onTap: () async {
                        if (![SocketState.CONNECTED].contains(SocketManager().state.value) || controller.isRestartingMessages.value) return;

                        controller.isRestartingMessages.value = true;

                        // Prevent restarting more than once every 30 seconds
                        int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                        if (controller.lastRestartMessages != null && now - controller.lastRestartMessages! < 1000 * 30) return;

                        // Save the last time we restarted
                        controller.lastRestartMessages = now;

                        // Create a temporary functon so we can call it easily
                        Function stopRestarting = () {
                          controller.isRestartingMessages.value = false;
                        };

                        // Execute the restart
                        try {
                          // If it fails or there is an endpoint error, stop the loader
                          await SocketManager().sendMessage("restart-messages-app", null, (_) {
                            stopRestarting();
                          }).catchError((_) {
                            stopRestarting();
                          });
                        } finally {
                          stopRestarting();
                        }
                      },
                      trailing: (!controller.isRestartingMessages.value)
                          ? Icon(Icons.refresh, color: Colors.grey)
                          : Container(
                          constraints: BoxConstraints(
                            maxHeight: 20,
                            maxWidth: 20,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                          )))),
                  Obx(() {
                    if (SettingsManager().settings.enablePrivateAPI.value) {
                      return Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 65.0),
                          child: SettingsDivider(color: headerColor),
                        ),
                      );
                    } else return SizedBox.shrink();
                  }),
                  Obx(() {
                    if (SettingsManager().settings.enablePrivateAPI.value
                        && (controller.serverVersionCode.value ?? 0) >= 41) {
                      return SettingsTile(
                          title: "Restart Private API",
                          subtitle: controller.isRestartingPrivateAPI.value && SocketManager().state.value == SocketState.CONNECTED
                              ? "Restart in progress..." : SocketManager().state.value == SocketState.CONNECTED ? "Restart the Private API" : "Disconnected, cannot restart",
                          backgroundColor: tileColor,
                          leading: SettingsLeadingIcon(
                            iosIcon: CupertinoIcons.exclamationmark_shield,
                            materialIcon: Icons.gpp_maybe,
                          ),
                          onTap: () async {
                            if (![SocketState.CONNECTED].contains(SocketManager().state.value) || controller.isRestartingPrivateAPI.value) return;

                            controller.isRestartingPrivateAPI.value = true;

                            // Prevent restarting more than once every 30 seconds
                            int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                            if (controller.lastRestartPrivateAPI != null && now - controller.lastRestartPrivateAPI! < 1000 * 30) return;

                            // Save the last time we restarted
                            controller.lastRestartPrivateAPI = now;

                            // Create a temporary functon so we can call it easily
                            Function stopRestarting = () {
                              controller.isRestartingPrivateAPI.value = false;
                            };

                            // Execute the restart
                            try {
                              // If it fails or there is an endpoint error, stop the loader
                              await SocketManager().sendMessage("restart-private-api", null, (_) {
                                stopRestarting();
                              }).catchError((_) {
                                stopRestarting();
                              });
                            } finally {
                              stopRestarting();
                            }
                          },
                          trailing: (!controller.isRestartingPrivateAPI.value)
                              ? Icon(Icons.refresh, color: Colors.grey)
                              : Container(
                              constraints: BoxConstraints(
                                maxHeight: 20,
                                maxWidth: 20,
                              ),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                              )));
                    } else return SizedBox.shrink();
                  }),
                  Container(
                    color: tileColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 65.0),
                      child: SettingsDivider(color: headerColor),
                    ),
                  ),
                  Obx(() => SettingsTile(
                      title: "Restart BlueBubbles Server",
                      subtitle: (controller.isRestarting.value)
                          ? "Restart in progress..."
                          : "This will briefly disconnect you",
                      backgroundColor: tileColor,
                      leading: SettingsLeadingIcon(
                        iosIcon: CupertinoIcons.desktopcomputer,
                        materialIcon: Icons.dvr,
                      ),
                      onTap: () async {
                        if (controller.isRestarting.value) return;

                        controller.isRestarting.value = true;

                        // Prevent restarting more than once every 30 seconds
                        int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                        if (controller.lastRestart != null && now - controller.lastRestart! < 1000 * 30) return;

                        // Save the last time we restarted
                        controller.lastRestart = now;

                        Function stopRestarting = () {
                          controller.isRestarting.value = false;
                        };

                        // Perform the restart
                        try {
                          MethodChannelInterface().invokeMethod(
                              "set-next-restart", {"value": DateTime.now().toUtc().millisecondsSinceEpoch});
                        } finally {
                          stopRestarting();
                        }

                        // After 5 seconds, remove the restarting message
                        Future.delayed(new Duration(seconds: 5), () {
                          stopRestarting();
                        });
                      },
                      trailing: (!controller.isRestarting.value)
                          ? Icon(Icons.refresh, color: Colors.grey)
                          : Container(
                              constraints: BoxConstraints(
                                maxHeight: 20,
                                maxWidth: 20,
                              ),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                              )))),
                  Container(color: tileColor, padding: EdgeInsets.only(top: 5.0)),
                  Container(
                    height: 30,
                    decoration: SettingsManager().settings.skin.value == Skins.iOS ? BoxDecoration(
                      color: headerColor,
                      border: Border(
                          top: BorderSide(color: Theme.of(context).dividerColor.lightenOrDarken(40), width: 0.3)
                      ),
                    ) : null,
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
      ),
    );
  }
}

class SyncDialog extends StatefulWidget {
  SyncDialog({Key? key}) : super(key: key);

  @override
  _SyncDialogState createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  String? errorCode;
  bool finished = false;
  String? message;
  double? progress;
  Duration? lookback;
  int page = 0;

  void syncMessages() async {
    if (lookback == null) return;

    DateTime now = DateTime.now().toUtc().subtract(lookback!);
    SocketManager().fetchMessages(null, after: now.millisecondsSinceEpoch)!.then((dynamic messages) {
      if (this.mounted) {
        setState(() {
          message = "Adding ${messages.length} messages...";
        });
      }

      MessageHelper.bulkAddMessages(null, messages, onProgress: (int progress, int length) {
        if (progress == 0 || length == 0) {
          this.progress = null;
        } else {
          this.progress = progress / length;
        }

        if (this.mounted)
          setState(() {
            message = "Adding $progress of $length (${((this.progress ?? 0) * 100).floor().toInt()}%)";
          });
      }).then((List<Message> items) {
        onFinish(true, items.length);
      });
    }).catchError((_) {
      onFinish(false, 0);
    });
  }

  void onFinish([bool success = true, int? total]) {
    if (!this.mounted) return;

    this.progress = 100;
    message = "Finished adding $total messages!";
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    String title = errorCode != null ? "Error!" : message ?? "";
    Widget content = Container();
    if (errorCode != null) {
      content = Text(errorCode!);
    } else {
      content = Container(
        height: 5,
        child: Center(
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white,
            valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
          ),
        ),
      );
    }

    List<Widget> actions = [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: Text(
          "Ok",
          style: Theme.of(context).textTheme.bodyText1!.apply(
                color: Theme.of(context).primaryColor,
              ),
        ),
      )
    ];

    if (page == 0) {
      title = "How far back would you like to go?";
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              "Days: ${lookback?.inDays ?? "1"}",
              style: Theme.of(context).textTheme.bodyText1,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Slider(
              value: lookback?.inDays.toDouble() ?? 1.0,
              onChanged: (double value) {
                if (!this.mounted) return;

                setState(() {
                  lookback = new Duration(days: value.toInt());
                });
              },
              label: lookback?.inDays.toString() ?? "1",
              divisions: 29,
              min: 1,
              max: 30,
            ),
          )
        ],
      );

      actions = [
        TextButton(
          onPressed: () {
            if (!this.mounted) return;
            if (lookback == null) lookback = new Duration(days: 1);
            page = 1;
            message = "Fetching messages...";
            setState(() {});
            syncMessages();
          },
          child: Text(
            "Sync",
            style: Theme.of(context).textTheme.bodyText1!.apply(
                  color: Theme.of(context).primaryColor,
                ),
          ),
        )
      ];
    }

    return AlertDialog(
      backgroundColor: Theme.of(context).backgroundColor,
      title: Text(title, style: Theme.of(context).textTheme.headline1),
      content: content,
      actions: actions,
    );
  }
}
