import 'dart:async';

import 'package:bluebubbles/app/layouts/settings/pages/server/connection_panel/connection_panel.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/models/models.dart' show ServerDetails;
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum IMessageStatsSource { server, local }

class ServerManagementPanelController extends StatefulController {
  final RxnInt latency = RxnInt();
  final RxnString fetchStatus = RxnString();
  final Rx<ServerDetails> serverDetails = Rx(const ServerDetails.empty());
  final RxBool helperBundleStatus = RxBool(false);
  final RxnDouble timeSync = RxnDouble();
  final RxMap<String, dynamic> serverStats = RxMap({});
  final RxMap<String, dynamic> localStats = RxMap({});
  final Rx<IMessageStatsSource> selectedStatsSource = IMessageStatsSource.server.obs;
  final RxBool isLoadingServerStats = RxBool(false);
  final RxBool isLoadingLocalStats = RxBool(false);
  final RxnString serverStatsErrorMessage = RxnString();
  final RxnString localStatsErrorMessage = RxnString();
  final RxBool hasAccountInfo = RxBool(false);

  // Restart trackers
  int? lastRestart;
  int? lastRestartMessages;
  int? lastRestartPrivateAPI;
  final RxBool isRestarting = false.obs;
  final RxBool isRestartingMessages = false.obs;
  final RxBool isRestartingPrivateAPI = false.obs;
  final RxDouble opacity = 1.0.obs;
  final RxnBool hasCheckedStats = RxnBool(false);

  @override
  void onInit() {
    super.onInit();
    serverDetails.value = SettingsSvc.serverDetails;
    selectedStatsSource.value = SettingsSvc.settings.iMessageStatsSource.value == 'local'
        ? IMessageStatsSource.local
        : IMessageStatsSource.server;
  }

  @override
  void onReady() {
    super.onReady();
    refreshServerStats();
    refreshLocalStats();
  }

  Future<void> setStatsSource(IMessageStatsSource source) async {
    selectedStatsSource.value = source;
    SettingsSvc.settings.iMessageStatsSource.value = source == IMessageStatsSource.local ? 'local' : 'server';
    await SettingsSvc.settings.saveOneAsync('iMessageStatsSource');
    if (source == IMessageStatsSource.local && localStats.isEmpty) {
      await refreshLocalStats();
    }
    if (source == IMessageStatsSource.server && serverStats.isEmpty) {
      await refreshServerStats();
    }
  }

  Map<String, dynamic> getActiveStatsMap() {
    return selectedStatsSource.value == IMessageStatsSource.local ? localStats : serverStats;
  }

  String? getActiveStatsError() {
    return selectedStatsSource.value == IMessageStatsSource.local
        ? localStatsErrorMessage.value
        : serverStatsErrorMessage.value;
  }

  bool isActiveStatsLoading() {
    return selectedStatsSource.value == IMessageStatsSource.local
        ? isLoadingLocalStats.value
        : isLoadingServerStats.value;
  }

  Future<bool> refreshSelectedStats() async {
    if (selectedStatsSource.value == IMessageStatsSource.local) {
      return refreshLocalStats();
    } else {
      return refreshServerStats();
    }
  }

  Future<void> getServerStats() async {
    await refreshServerStats();
  }

  Future<void> refreshServerConnectionInfo() async {
    hasCheckedStats.value = false;
    serverStatsErrorMessage.value = null;
    int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    try {
      await HttpSvc.server.ping();
      int later = DateTime.now().toUtc().millisecondsSinceEpoch;
      latency.value = later - now;
    } catch (_) {
      latency.value = null;
      serverStatsErrorMessage.value = "Could not connect to your server";
      hasCheckedStats.value = true;
    }

    await HttpSvc.server.info().then((response) {
      final String macOSVersionStr = response.data['data']['os_version'] ?? '0.0';
      final String serverVersionStr = response.data['data']['server_version'] ?? '0.0.0';
      final osParts = macOSVersionStr.split('.');
      serverDetails.value = ServerDetails(
        macOSVersion: int.tryParse(osParts.isNotEmpty ? osParts[0] : '0') ?? 0,
        macOSMinorVersion: int.tryParse(osParts.length > 1 ? osParts[1] : '0') ?? 0,
        serverVersion: serverVersionStr,
        serverVersionCode: ServerDetails.versionCodeFor(serverVersionStr),
        privateApiEnabled: response.data['data']['private_api'] ?? false,
        iCloudAccount: response.data['data']['detected_icloud'],
        proxyService: response.data['data']['proxy_service'],
        apiVersions: (response.data['data']['api_versions'] as List? ?? const []).whereType<int>().toList(),
        serverBuildVersion: response.data['data']['server_build_version'],
      );
      unawaited(SettingsSvc.updateServerDetails(serverDetails.value));
      helperBundleStatus.value = response.data['data']['helper_connected'] ?? false;
      timeSync.value = response.data['data']['macos_time_sync'];
      hasCheckedStats.value = true;
    }).catchError((_) {
      hasCheckedStats.value = null;
    });
  }

  Future<bool> refreshServerStats() async {
    isLoadingServerStats.value = true;
    serverStatsErrorMessage.value = null;
    try {
      final totalResponse = await HttpSvc.server.getTotalStats();
      if (totalResponse.data['status'] != 200) {
        throw Exception("Failed to load server totals");
      }

      final mediaResponse = await HttpSvc.server.getMediaStats();
      if (mediaResponse.data['status'] != 200) {
        throw Exception("Failed to load server media stats");
      }

      final merged = <String, dynamic>{};
      merged.addAll(totalResponse.data['data'] ?? {});
      merged.addAll(mediaResponse.data['data'] ?? {});
      serverStats
        ..clear()
        ..addAll(merged);
      await refreshServerConnectionInfo();
      return true;
    } catch (_) {
      serverStatsErrorMessage.value = "Could not retrieve statistics from your server";
      await refreshServerConnectionInfo();
      return false;
    } finally {
      isLoadingServerStats.value = false;
    }
  }

  Future<bool> refreshLocalStats() async {
    isLoadingLocalStats.value = true;
    localStatsErrorMessage.value = null;

    if (kIsWeb) {
      localStatsErrorMessage.value = "Local stats are unavailable on web builds";
      isLoadingLocalStats.value = false;
      return false;
    }

    try {
      await Database.waitForInit();
      final statsMap = Database.runInTransaction(TxMode.read, () {
        final messageQuery = Database.messages.query(Message_.dateDeleted.isNull()).build();
        final chatQuery = Database.chats.query(Chat_.dateDeleted.isNull()).build();
        final attachmentQuery = Database.attachments.query(Attachment_.mimeType.notNull()).build();
        final imageQuery = Database.attachments.query(Attachment_.mimeType.startsWith("image/")).build();
        final videoQuery = Database.attachments.query(Attachment_.mimeType.startsWith("video/")).build();
        final locationQuery = Database.attachments
            .query(Attachment_.mimeType.equals("text/x-vlocation").or(Attachment_.uti.equals("public.vlocation")))
            .build();

        try {
          return <String, dynamic>{
            'messages': messageQuery.count(),
            'chats': chatQuery.count(),
            'handles': Database.handles.count(),
            'attachments': attachmentQuery.count(),
            'images': imageQuery.count(),
            'videos': videoQuery.count(),
            'locations': locationQuery.count(),
          };
        } finally {
          messageQuery.close();
          chatQuery.close();
          attachmentQuery.close();
          imageQuery.close();
          videoQuery.close();
          locationQuery.close();
        }
      });

      localStats
        ..clear()
        ..addAll(statsMap);
      return true;
    } catch (_) {
      localStatsErrorMessage.value = "Failed to load local database statistics";
      return false;
    } finally {
      isLoadingLocalStats.value = false;
    }
  }
}

class ServerManagementPanel extends CustomStateful<ServerManagementPanelController> {
  ServerManagementPanel({super.key}) : super(parentController: Get.put(ServerManagementPanelController()));

  @override
  State<ServerManagementPanel> createState() => _ServerManagementPanelState();
}

class _ServerManagementPanelState extends CustomState<ServerManagementPanel, void, ServerManagementPanelController> {
  @override
  Widget build(BuildContext context) {
    return ConnectionPanel(parentController: controller);
  }
}
