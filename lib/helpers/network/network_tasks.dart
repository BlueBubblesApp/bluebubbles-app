import 'dart:async';

import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart';

class NetworkTasks {
  static Future<void> onConnect() async {
    if (ss.settings.finishedSetup.value) {
      await fcm.registerDevice();
      await sync.startIncrementalSync();
      await ss.getServerDetails(refresh: true);
      ss.checkServerUpdate();
      ss.checkClientUpdate();
      // scan if server is on localhost
      if (!kIsWeb && ss.settings.localhostPort.value != null) {
        detectLocalhost();
      }

      if (kIsWeb && chats.chats.isEmpty) {
        Get.reload<ChatsService>(force: true);
        await chats.init();
      }
      if (kIsWeb && cs.contacts.isEmpty) {
        await cs.refreshContacts();
      }
    }
  }

  static Future<void> detectLocalhost() async {
    final wifiIP = await NetworkInfo().getWifiIP();
    if (wifiIP != null) {
      final stream = HostScanner.scanDevicesForSinglePort(
        wifiIP.substring(0, wifiIP.lastIndexOf('.')),
        int.parse(ss.settings.localhostPort.value!),
      );
      Set<ActiveHost> hosts = {};
      stream.listen((host) {
        hosts.add(host);
      }, onDone: () async {
        String? address;
        for (ActiveHost h in hosts) {
          final response = await http.dio.get("http://${hosts.first.address}:${ss.settings.localhostPort.value!}");
          if (response.data.toString().contains("BlueBubbles")) {
            address = h.address;
            break;
          }
        }
        if (address != null) {
          http.originOverride = "http://$address:${ss.settings.localhostPort.value}/api/v1";
        } else {
          http.originOverride = null;
        }
      }, onError: (_,__) {
        http.originOverride = null;
      });
    } else {
      http.originOverride = null;
    }
  }
}