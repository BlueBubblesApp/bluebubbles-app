import 'package:animated_size_and_fade/animated_size_and_fade.dart';
import 'dart:convert';

import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/app/layouts/settings/dialogs/custom_headers_dialog.dart';
import 'package:bluebubbles/app/layouts/settings/dialogs/sync_dialog.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/imessage_stats/imessage_stats_page.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/oauth_panel.dart';
import 'package:bluebubbles/app/layouts/settings/pages/server/server_management_panel.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/layouts/setup/dialogs/manual_entry_dialog.dart';
import 'package:bluebubbles/app/layouts/setup/pages/sync/qr_code_scanner.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

class StatusItemConfig {
  final String key;
  final String label;
  final IconData iosIcon;
  final IconData materialIcon;
  final Color containerColor;

  const StatusItemConfig({
    required this.key,
    required this.label,
    required this.iosIcon,
    required this.materialIcon,
    required this.containerColor,
  });
}

class InfoItemConfig {
  final String key;
  final String label;
  final IconData iosIcon;
  final IconData materialIcon;
  final Color containerColor;
  final void Function(BuildContext, ServerManagementPanelController)? onTap;

  const InfoItemConfig({
    required this.key,
    required this.label,
    required this.iosIcon,
    required this.materialIcon,
    required this.containerColor,
    this.onTap,
  });
}

mixin ConnectionPanelHelpersMixin {
  static const List<StatusItemConfig> kStatusItems = [
    StatusItemConfig(
      key: 'api',
      label: 'API Connection',
      iosIcon: CupertinoIcons.wifi,
      materialIcon: Icons.wifi,
      containerColor: Colors.green,
    ),
    StatusItemConfig(
      key: 'socket',
      label: 'Socket',
      iosIcon: CupertinoIcons.bolt,
      materialIcon: Icons.electric_bolt,
      containerColor: Colors.blue,
    ),
    StatusItemConfig(
      key: 'privateApi',
      label: 'Private API',
      iosIcon: CupertinoIcons.lock_shield,
      materialIcon: Icons.security,
      containerColor: Colors.orange,
    ),
    StatusItemConfig(
      key: 'helperBundle',
      label: 'Helper Bundle',
      iosIcon: CupertinoIcons.plus_bubble,
      materialIcon: Icons.extension,
      containerColor: Colors.purple,
    ),
  ];

  static final List<InfoItemConfig> kInfoItems = [
    const InfoItemConfig(
      key: 'serverVersion',
      label: 'Server Version',
      iosIcon: CupertinoIcons.desktopcomputer,
      materialIcon: Icons.dvr,
      containerColor: Colors.blueGrey,
    ),
    const InfoItemConfig(
      key: 'macosVersion',
      label: 'macOS Version',
      iosIcon: CupertinoIcons.macwindow,
      materialIcon: Icons.computer,
      containerColor: Colors.blueGrey,
    ),
    InfoItemConfig(
      key: 'serverUrl',
      label: 'Server URL',
      iosIcon: CupertinoIcons.link,
      materialIcon: Icons.link,
      containerColor: Colors.teal,
      onTap: (context, controller) {
        Clipboard.setData(ClipboardData(text: HttpSvc.origin));
        if (!Platform.isAndroid || (FilesystemSvc.androidInfo?.version.sdkInt ?? 0) < 33) {
          showSnackbar("Copied", "Server address copied to clipboard!");
        }
      },
    ),
    const InfoItemConfig(
      key: 'firebaseDb',
      label: 'Firebase DB',
      iosIcon: CupertinoIcons.flame,
      materialIcon: Icons.local_fire_department,
      containerColor: Colors.orange,
    ),
    const InfoItemConfig(
      key: 'icloudAccount',
      label: 'iCloud Account',
      iosIcon: CupertinoIcons.cloud,
      materialIcon: Icons.cloud,
      containerColor: Colors.blue,
    ),
    const InfoItemConfig(
      key: 'proxyService',
      label: 'Proxy Service',
      iosIcon: CupertinoIcons.arrow_2_squarepath,
      materialIcon: Icons.swap_horiz,
      containerColor: Colors.purple,
    ),
    const InfoItemConfig(
      key: 'latency',
      label: 'Latency',
      iosIcon: CupertinoIcons.timer,
      materialIcon: Icons.speed,
      containerColor: Colors.blue,
    ),
    const InfoItemConfig(
      key: 'timeSync',
      label: 'Time Sync',
      iosIcon: CupertinoIcons.clock,
      materialIcon: Icons.access_time,
      containerColor: Colors.teal,
    ),
  ];

  /// Returns a display string for the given info/status key, using "—" when not yet loaded.
  String resolveValue(ServerManagementPanelController controller, String key) {
    final bool redact = SettingsSvc.settings.redactedMode.value;
    switch (key) {
      case 'api':
        final checked = controller.hasCheckedStats.value;
        if (checked == null) return 'Disconnected';
        if (checked == true) return 'Connected';
        return 'Connecting';
      case 'socket':
        return SocketSvc.state.value.name.capitalizeFirst ?? SocketSvc.state.value.name;
      case 'privateApi':
        final enabled = controller.serverDetails.value.privateApiEnabled;
        if (enabled == null) return '—';
        return enabled ? 'Enabled' : 'Disabled';
      case 'helperBundle':
        if (controller.hasCheckedStats.value == false) return '—';
        return controller.helperBundleStatus.value ? 'Connected' : 'Disconnected';
      case 'latency':
        final l = controller.latency.value;
        return l != null ? '$l ms' : '—';
      case 'serverVersion':
        if (redact) return 'Redacted';
        final v = controller.serverDetails.value.serverVersion;
        return v.isNotEmpty ? v : '—';
      case 'macosVersion':
        if (redact) return 'Redacted';
        final v = controller.serverDetails.value.macOSVersionString;
        return v.isNotEmpty ? v : '—';
      case 'serverUrl':
        if (redact) return 'Redacted';
        final o = HttpSvc.origin;
        return o.isNotEmpty ? o : '—';
      case 'firebaseDb':
        if (SettingsSvc.fcmData.isNull) return '—';
        return isNullOrEmptyString(SettingsSvc.fcmData.firebaseURL) ? 'Firestore' : 'Realtime';
      case 'icloudAccount':
        if (redact) return 'Redacted';
        return controller.serverDetails.value.iCloudAccount ?? '—';
      case 'proxyService':
        final p = controller.serverDetails.value.proxyService;
        return p != null ? (p.capitalizeFirst ?? p) : '—';
      case 'timeSync':
        final t = controller.timeSync.value;
        return t != null ? '${t.toStringAsFixed(3)}s' : '—';
      default:
        return '—';
    }
  }

  /// Returns a display color for a status key, using `getIndicatorColor`.
  Color resolveStatusColor(ServerManagementPanelController controller, String key) {
    switch (key) {
      case 'api':
        final checked = controller.hasCheckedStats.value;
        if (checked == null) return getIndicatorColor(SocketState.disconnected);
        if (checked == true) return getIndicatorColor(SocketState.connected);
        return getIndicatorColor(SocketState.connecting);
      case 'socket':
        return getIndicatorColor(SocketSvc.state.value);
      case 'privateApi':
        final enabled = controller.serverDetails.value.privateApiEnabled;
        return getIndicatorColor(enabled == true ? SocketState.connected : SocketState.disconnected);
      case 'helperBundle':
        return getIndicatorColor(
            controller.helperBundleStatus.value ? SocketState.connected : SocketState.disconnected);
      case 'timeSync':
        final t = controller.timeSync.value;
        if (t == null) return getIndicatorColor(SocketState.disconnected);
        return getIndicatorColor(t < 1 ? SocketState.connected : SocketState.disconnected);
      default:
        return getIndicatorColor(SocketState.connected);
    }
  }

  /// Builds the QR code AppBar action (only shown when FCM is configured).
  Widget? buildQrCodeAction(BuildContext context) {
    if (SettingsSvc.fcmData.isNull) return null;
    return IconButton(
      icon: const Icon(Icons.qr_code),
      tooltip: "Show QR Code",
      onPressed: () => _showQrDialog(context),
    );
  }

  void _showQrDialog(BuildContext context) {
    final List<dynamic> json = [
      SettingsSvc.settings.guidAuthKey.value,
      SettingsSvc.settings.serverAddress.value,
      SettingsSvc.fcmData.projectID,
      SettingsSvc.fcmData.storageBucket,
      SettingsSvc.fcmData.apiKey,
      SettingsSvc.fcmData.firebaseURL,
      SettingsSvc.fcmData.clientID,
      SettingsSvc.fcmData.applicationID,
    ];
    final String qrtext = jsonEncode(json);
    showBBDialog(
      context: context,
      title: "QR Code",
      content: AspectRatio(
        aspectRatio: 1,
        child: SizedBox(
          height: 320,
          width: 320,
          child: QrImageView(
            data: qrtext,
            version: QrVersions.auto,
            size: 320,
            gapless: true,
            backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
            eyeStyle: QrEyeStyle(color: context.theme.colorScheme.onSurfaceVariant),
            dataModuleStyle: QrDataModuleStyle(color: context.theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
      actions: [
        BBDialogAction(
          text: "Dismiss",
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }

  /// The "View Stats" tile — always shows something regardless of connection/load state.
  Widget buildViewStatsSection(
    BuildContext context,
    ServerManagementPanelController controller,
    Color tileColor,
  ) {
    return SettingsTile(
      title: "iMessage Statistics",
      subtitle: "Get an overview of your iMessage usage and statistics",
      backgroundColor: tileColor,
      leading: const SettingsLeadingIcon(
        iosIcon: CupertinoIcons.chart_bar_square,
        materialIcon: Icons.stacked_bar_chart,
        containerColor: Colors.green,
      ),
      trailing: Obx(() => Icon(
            SettingsSvc.settings.skin.value != Skins.Material ? CupertinoIcons.chevron_right : Icons.chevron_right,
            color: context.theme.colorScheme.outline.withValues(alpha: 0.5),
            size: 18,
          )),
      onTap: () {
        NavigationSvc.pushSettings(
          context,
          IMessageStatsPage(parentController: controller),
        );
      },
    );
  }

  /// Connection & Sync section (lifted verbatim from original ServerManagementPanel).
  Widget buildConnectionSyncSection(
    BuildContext context,
    ServerManagementPanelController controller,
    Color tileColor,
    Color headerColor,
    TextStyle? iosSubtitle,
    TextStyle? materialSubtitle,
    IncrementalSyncManager? Function() getManager,
    void Function(IncrementalSyncManager?) setManager,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Connection & Sync"),
        Obx(() => SettingsSection(
          backgroundColor: tileColor,
          children: [
            SettingsTile(
              title: "Re-configure with BlueBubbles Server",
              subtitle:
                  kIsWeb || kIsDesktop ? "Click for manual entry" : "Tap to scan QR code\nLong press for manual entry",
              isThreeLine: kIsWeb || kIsDesktop ? false : true,
              leading: const SettingsLeadingIcon(
                iosIcon: CupertinoIcons.gear,
                materialIcon: Icons.room_preferences,
                containerColor: Colors.blueAccent,
              ),
              onLongPress: kIsWeb || kIsDesktop
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (connectContext) => ManualEntryDialog(
                          onConnect: () => Navigator.of(context, rootNavigator: true).pop(),
                          onClose: () => Navigator.of(context, rootNavigator: true).pop(),
                        ),
                      );
                    },
              onTap: kIsWeb || kIsDesktop
                  ? () async {
                      await showDialog(
                        context: context,
                        builder: (connectContext) => ManualEntryDialog(
                          onConnect: () => Navigator.of(context, rootNavigator: true).pop(),
                          onClose: () => Navigator.of(context, rootNavigator: true).pop(),
                        ),
                      );
                    }
                  : () async {
                      List<dynamic>? fcmData;
                      try {
                        fcmData = jsonDecode(
                          await Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (BuildContext context) => const QRCodeScanner(),
                            ),
                          ),
                        );
                      } catch (e) {
                        return;
                      }
                      if (fcmData != null && fcmData[0] != null && sanitizeServerAddress(address: fcmData[1]) != null) {
                        final data = FCMData(
                          projectID: fcmData[2],
                          storageBucket: fcmData[3],
                          apiKey: fcmData[4],
                          firebaseURL: fcmData[5],
                          clientID: fcmData[6],
                          applicationID: fcmData[7],
                        );
                        SettingsSvc.settings.guidAuthKey.value = fcmData[0];
                        await saveNewServerUrl(fcmData[1]);
                        await SettingsSvc.saveFCMData(data);
                      }
                    },
            ),
            if (!kIsWeb) const SettingsDivider(),
            if (!kIsWeb)
              Obx(
                () => SettingsTile(
                  title: "Manually Sync Messages",
                  subtitle: SocketSvc.state.value == SocketState.connected
                      ? "Tap to sync messages"
                      : "Disconnected, cannot sync",
                  backgroundColor: tileColor,
                  leading: SettingsLeadingIcon(
                    iosIcon: CupertinoIcons.arrow_2_circlepath,
                    materialIcon: Icons.sync,
                    containerColor: Colors.yellow[700],
                  ),
                  onTap: () async {
                    if (SocketSvc.state.value != SocketState.connected) return;
                    final mgr = getManager();
                    if (mgr != null) {
                      showDialog(
                        context: context,
                        builder: (context) => SyncDialog(manager: mgr),
                      );
                    } else {
                      final date = await showTimeframePicker("How Far Back?", context, showHourPicker: false);
                      if (date == null) return;
                      try {
                        SyncSvc.isIncrementalSyncing.value = true;
                        final newMgr = IncrementalSyncManager(startTimestamp: date.millisecondsSinceEpoch);
                        setManager(newMgr);
                        showDialog(
                          context: context,
                          builder: (context) => SyncDialog(manager: newMgr),
                        );
                        await newMgr.start();
                      } catch (e, s) {
                        Logger.warn("Incremental sync failed", error: e, trace: s, tag: 'ConnectionPanel');
                      }
                      Navigator.of(context, rootNavigator: true).pop();
                      setManager(null);
                      SyncSvc.isIncrementalSyncing.value = false;
                    }
                  },
                ),
              ),
            if (!kIsWeb) const SettingsDivider(),
            SettingsTile(
              leading: const SettingsLeadingIcon(
                iosIcon: CupertinoIcons.pencil,
                materialIcon: Icons.edit,
                containerColor: Colors.teal,
              ),
              title: "Configure Custom Headers",
              subtitle: "Add or edit custom headers to connect to your server",
              backgroundColor: tileColor,
              onTap: () async {
                final result = await showCustomHeadersDialog(context);
                if (result) SocketSvc.restartSocket();
              },
            ),
            const SettingsDivider(),
            SettingsTile(
              leading: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Obx(() => Material(
                        shape: SettingsSvc.settings.skin.value == Skins.Samsung
                            ? SquircleBorder(
                                side: BorderSide(
                                  color: context.theme.colorScheme.outline.withValues(alpha: 0.5),
                                  width: 1.0,
                                ),
                              )
                            : null,
                        color: Colors.transparent,
                        borderRadius: SettingsSvc.settings.skin.value == Skins.iOS ? BorderRadius.circular(6) : null,
                        child: SizedBox(
                          width: 31,
                          height: 31,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.5),
                                    blurRadius: 0,
                                    spreadRadius: 0.5,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  "assets/images/google-sign-in.png",
                                  width: 33,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )),
                ],
              ),
              title: "Sign in with Google",
              subtitle: "Fetch Firebase Config by Signing in with Google",
              backgroundColor: tileColor,
              onTap: () => NavigationSvc.pushSettings(context, const OauthPanel()),
              trailing: const ThemeSwitcher(
                iOSSkin: Icon(CupertinoIcons.chevron_forward),
                materialSkin: Icon(Icons.chevron_right),
              ),
            ),
            const SettingsDivider(),
            SettingsTile(
              leading: const SettingsLeadingIcon(
                iosIcon: CupertinoIcons.refresh,
                materialIcon: Icons.refresh,
                containerColor: Colors.blueAccent,
              ),
              title: "Fetch Latest URL",
              subtitle: "Forcefully fetch latest URL from Firebase",
              backgroundColor: tileColor,
              onTap: () async {
                await fdb.fetchFirebaseConfig();
                String? newUrl = await fdb.fetchNewUrl();
                showSnackbar("Notice", "Fetched URL: $newUrl");
                SocketSvc.restartSocket();
              },
            ),
            if (!kIsWeb) const SettingsDivider(),
            if (!kIsWeb)
              Obx(() => SettingsSwitch(
                    initialVal: SettingsSvc.settings.localhostPort.value != null,
                    title: "Detect Localhost Address",
                    subtitle: SettingsSvc.settings.localhostPort.value != null
                        ? "Configured Port: ${SettingsSvc.settings.localhostPort.value}"
                        : "Look up localhost address for a faster direct connection",
                    backgroundColor: tileColor,
                    leading: const SettingsLeadingIcon(
                      iosIcon: CupertinoIcons.wifi,
                      materialIcon: Icons.wifi,
                      containerColor: Colors.green,
                    ),
                    onChanged: (bool val) async {
                      if (val) {
                        final TextEditingController portController = TextEditingController();
                        await showBBDialog(
                          context: context,
                          title: "Enter Server Port",
                          content: TextField(
                            controller: portController,
                            decoration: const InputDecoration(
                              labelText: "Port Number",
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          actions: [
                            BBDialogAction(
                              text: "Cancel",
                              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                            ),
                            BBDialogAction(
                              text: "OK",
                              isDefault: true,
                              onPressed: () async {
                                if (portController.text.isEmpty || !portController.text.isNumericOnly) {
                                  showSnackbar("Error", "Enter a valid port!");
                                  return;
                                }
                                Navigator.of(context, rootNavigator: true).pop();
                                SettingsSvc.settings.localhostPort.value = portController.text;
                              },
                            ),
                          ],
                        );
                      } else {
                        SettingsSvc.settings.localhostPort.value = null;
                      }
                      await SettingsSvc.settings.saveOneAsync('useLocalhost');
                      if (SettingsSvc.settings.localhostPort.value == null) {
                        NetworkTasks.setOriginOverride(null);
                      } else {
                        NetworkTasks.detectLocalhost(createSnackbar: true);
                      }
                    },
                  )),
            if (!kIsWeb && SettingsSvc.settings.localhostPort.value != null) const SettingsDivider(),
            if (!kIsWeb && SettingsSvc.settings.localhostPort.value != null)
              SettingsSwitch(
                initialVal: SettingsSvc.settings.useLocalIpv6.value,
                title: "Use IPv6",
                subtitle: "Do not enable this unless your environment supports IPv6",
                isThreeLine: true,
                onChanged: (bool val) async {
                  SettingsSvc.settings.useLocalIpv6.value = val;
                  await SettingsSvc.settings.saveOneAsync('useLocalIpv6');
                  NetworkTasks.detectLocalhost(createSnackbar: true);
                },
                leading: const SettingsLeadingIcon(
                  iosIcon: CupertinoIcons.globe,
                  materialIcon: Icons.network_check_outlined,
                  containerColor: Colors.blue,
                ),
              ),
          ],
        )),
      ],
    );
  }

  /// Server Actions section (lifted verbatim from original ServerManagementPanel).
  Widget buildServerActionsSection(
    BuildContext context,
    ServerManagementPanelController controller,
    Color tileColor,
    Color headerColor,
    TextStyle? iosSubtitle,
    TextStyle? materialSubtitle,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsHeader(iosSubtitle: iosSubtitle, materialSubtitle: materialSubtitle, text: "Server Actions"),
        SettingsSection(
          backgroundColor: tileColor,
          children: [
            Obx(() => SettingsTile(
                  title: "Fetch${kIsWeb || kIsDesktop ? "" : " & Share"} Server Logs",
                  subtitle: controller.fetchStatus.value ??
                      (SocketSvc.state.value == SocketState.connected
                          ? "Tap to fetch logs"
                          : "Disconnected, cannot fetch logs"),
                  backgroundColor: tileColor,
                  leading: const SettingsLeadingIcon(
                    iosIcon: CupertinoIcons.doc_plaintext,
                    materialIcon: Icons.article,
                    containerColor: Colors.lightBlue,
                  ),
                  onTap: () {
                    if (SocketSvc.state.value != SocketState.connected) return;
                    controller.fetchStatus.value = "Fetching logs, please wait...";
                    HttpSvc.server.getLogs().then((response) async {
                      if (kIsDesktop) {
                        final downloadsPath = await FilesystemSvc.downloadsDirectory;
                        await File(join(downloadsPath, "main.log")).writeAsString(response.data['data']);
                        controller.fetchStatus.value = null;
                        return showSnackbar('Success', 'Saved logs to $downloadsPath!');
                      }
                      if (kIsWeb) {
                        final bytes = utf8.encode(response.data['data']);
                        final content = base64.encode(bytes);
                        html.AnchorElement(href: "data:application/octet-stream;charset=utf-16le;base64,$content")
                          ..setAttribute("download", "main.log")
                          ..click();
                        controller.fetchStatus.value = null;
                        return;
                      }
                      File logFile = File(join(FilesystemSvc.attachmentsPath, 'main.log'));
                      if (await logFile.exists()) await logFile.delete();
                      await logFile.writeAsString(response.data['data']);
                      try {
                        Share.files([logFile.absolute.path]);
                        controller.fetchStatus.value = null;
                      } catch (ex) {
                        controller.fetchStatus.value = "Failed to share file! ${ex.toString()}";
                      }
                    }).catchError((_) {
                      controller.fetchStatus.value = "Failed to fetch logs!";
                    });
                  },
                )),
            const SettingsDivider(),
            Obx(() => SettingsTile(
                  title: "Restart iMessage",
                  subtitle: controller.isRestartingMessages.value && SocketSvc.state.value == SocketState.connected
                      ? "Restart in progress..."
                      : SocketSvc.state.value == SocketState.connected
                          ? "Restart the iMessage app"
                          : "Disconnected, cannot restart",
                  backgroundColor: tileColor,
                  leading: const SettingsLeadingIcon(
                    iosIcon: CupertinoIcons.chat_bubble,
                    materialIcon: Icons.sms,
                    containerColor: Colors.blueAccent,
                  ),
                  onTap: () async {
                    if (SocketSvc.state.value != SocketState.connected || controller.isRestartingMessages.value) {
                      return;
                    }
                    controller.isRestartingMessages.value = true;
                    int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                    if (controller.lastRestartMessages != null && now - controller.lastRestartMessages! < 1000 * 30) {
                      return;
                    }
                    controller.lastRestartMessages = now;
                    HttpSvc.server.restartImessage().then((_) {
                      controller.isRestartingMessages.value = false;
                    }).catchError((_) {
                      controller.isRestartingMessages.value = false;
                    });
                  },
                  trailing: Obx(() => (!controller.isRestartingMessages.value)
                      ? Icon(Icons.refresh, color: context.theme.colorScheme.outline)
                      : Container(
                          constraints: const BoxConstraints(maxHeight: 20, maxWidth: 20),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                          ))),
                )),
            const SettingsDivider(),
            Obx(() => AnimatedSizeAndFade.showHide(
                  show: SettingsSvc.settings.enablePrivateAPI.value &&
                      controller.serverDetails.value.supportsRestartPrivateApi,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SettingsTile(
                        title: "Restart Private API & Services",
                        subtitle:
                            controller.isRestartingPrivateAPI.value && SocketSvc.state.value == SocketState.connected
                                ? "Restart in progress..."
                                : SocketSvc.state.value == SocketState.connected
                                    ? "Restart the Private API"
                                    : "Disconnected, cannot restart",
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.exclamationmark_shield,
                          materialIcon: Icons.gpp_maybe,
                          containerColor: Colors.orange,
                        ),
                        onTap: () async {
                          if (SocketSvc.state.value != SocketState.connected ||
                              controller.isRestartingPrivateAPI.value) {
                            return;
                          }
                          controller.isRestartingPrivateAPI.value = true;
                          int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                          if (controller.lastRestartPrivateAPI != null &&
                              now - controller.lastRestartPrivateAPI! < 1000 * 30) {
                            return;
                          }
                          controller.lastRestartPrivateAPI = now;
                          HttpSvc.server.softRestart().then((_) {
                            controller.isRestartingPrivateAPI.value = false;
                          }).catchError((_) {
                            controller.isRestartingPrivateAPI.value = false;
                          });
                        },
                        trailing: (!controller.isRestartingPrivateAPI.value)
                            ? Icon(Icons.refresh, color: context.theme.colorScheme.outline)
                            : Container(
                                constraints: const BoxConstraints(maxHeight: 20, maxWidth: 20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                )),
                      ),
                      Container(
                        color: tileColor,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 62.0),
                          child: SettingsDivider(color: context.theme.colorScheme.surfaceVariant),
                        ),
                      ),
                    ],
                  ),
                )),
            Obx(() => SettingsTile(
                  title: "Restart BlueBubbles Server",
                  subtitle:
                      controller.isRestarting.value ? "Restart in progress..." : "This will briefly disconnect you",
                  leading: const SettingsLeadingIcon(
                    iosIcon: CupertinoIcons.desktopcomputer,
                    materialIcon: Icons.dvr,
                    containerColor: Colors.redAccent,
                  ),
                  onTap: () async {
                    if (controller.isRestarting.value) return;
                    controller.isRestarting.value = true;
                    int now = DateTime.now().toUtc().millisecondsSinceEpoch;
                    if (controller.lastRestart != null && now - controller.lastRestart! < 1000 * 30) return;
                    controller.lastRestart = now;
                    try {
                      if (Platform.isAndroid) {
                        try {
                          await MethodChannelSvc.actions.setNextRestart(
                            value: DateTime.now().toUtc().millisecondsSinceEpoch,
                          );
                        } catch (e, s) {
                          Logger.error("Failed to update Firebase Database!", error: e, trace: s);
                          showSnackbar("Error", "Something went wrong when updating Firebase Database!");
                        }
                      } else {
                        if (!isNullOrEmpty(SettingsSvc.fcmData.firebaseURL)) {
                          var db = FirebaseDatabase(databaseURL: SettingsSvc.fcmData.firebaseURL);
                          var ref = db.reference().child('config').child('nextRestart');
                          await ref.set(DateTime.now().toUtc().millisecondsSinceEpoch);
                        } else {
                          await HttpSvc.firebase.setRestartDateCF(SettingsSvc.fcmData.projectID!);
                        }
                      }
                    } finally {
                      controller.isRestarting.value = false;
                    }
                  },
                  trailing: (!controller.isRestarting.value)
                      ? Icon(Icons.refresh, color: context.theme.colorScheme.outline)
                      : Container(
                          constraints: const BoxConstraints(maxHeight: 20, maxWidth: 20),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                          )),
                )),
            Obx(() => AnimatedSizeAndFade.showHide(
                  show: controller.serverDetails.value.supportsPrivateApiStatus,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SettingsDivider(),
                      SettingsTile(
                        title: "Check for Server Updates",
                        subtitle: SocketSvc.state.value == SocketState.connected
                            ? "Check for new BlueBubbles Server updates"
                            : "Disconnected, cannot check for updates",
                        backgroundColor: tileColor,
                        leading: const SettingsLeadingIcon(
                          iosIcon: CupertinoIcons.desktopcomputer,
                          materialIcon: Icons.dvr,
                          containerColor: Colors.green,
                        ),
                        onTap: () async {
                          if (SocketSvc.state.value != SocketState.connected) return;
                          await SettingsSvc.checkServerUpdate();
                        },
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ],
    );
  }
}
