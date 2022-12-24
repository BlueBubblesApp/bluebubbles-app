import 'dart:async';

import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
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
    final schemes = ['https', 'http'];
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
          for (String scheme in schemes) {
            String addr = "$scheme://${h.address}:${ss.settings.localhostPort.value!}";
            try {
              final response = await http.dio.get(addr);
              if (response.data.toString().contains("BlueBubbles")) {
                address = addr;
                break;
              }
            } catch (ex) {
              Logger.debug('Failed to connect to localhost addres: $addr');
            }
          }
        }
        if (address != null) {
          http.originOverride = address;
        } else {
          http.originOverride = null;
        }
      }, onError: (_, __) {
        http.originOverride = null;
      });
    } else {
      http.originOverride = null;
    }
  }
}
