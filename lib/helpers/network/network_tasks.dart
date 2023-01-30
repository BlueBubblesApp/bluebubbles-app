import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart'
    if (dart.library.html) 'package:bluebubbles/models/html/network_tools.dart';

class NetworkTasks {
  static Future<void> onConnect() async {
    if (ss.settings.finishedSetup.value) {
      if (cm.activeChat != null) {
        socket.sendMessage("update-typing-status", {"chatGuid": cm.activeChat!.chat.guid});
      }
      await fcm.registerDevice();
      await sync.startIncrementalSync();
      await ss.getServerDetails(refresh: true);

      try {
        ss.checkServerUpdate();
      } catch (ex) {
        Logger.warn("Failed to check for server update: ${ex.toString()}");
      }

      try {
        ss.checkClientUpdate();
      } catch (ex) {
        Logger.warn("Failed to check for client update: ${ex.toString()}");
      }

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

  static Future<void> detectLocalhost({bool createSnackbar = false}) async {
    ConnectivityResult status = await (Connectivity().checkConnectivity());
    if (status != ConnectivityResult.wifi) {
      http.originOverride = null;
      return;
    }
    final wifiIP = await NetworkInfo().getWifiIP();
    final schemes = ['http', 'https'];
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
          if (createSnackbar) {
            showSnackbar('Localhost Detected', 'Connected to $address');
          }

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
