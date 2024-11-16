import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart'
    if (dart.library.html) 'package:bluebubbles/models/html/network_tools.dart';

class NetworkTasks {
  static Future<void> onConnect() async {
    if (ss.settings.finishedSetup.value) {
      
      // Separate functionality for android vs. other
      if (!Platform.isAndroid) {
        await sync.startIncrementalSync();
      } else {
        // Only start incremental sync if the app is active and the previous state wasn't just hidden
        // or if the app was never resumed before
        if (!ls.hasResumed || (ls.currentState == AppLifecycleState.resumed && ls.wasPaused)) {
          await sync.startIncrementalSync();
        }
      }

      // scan if server is on localhost
      if (!kIsWeb && ss.settings.localhostPort.value != null) {
        detectLocalhost();
      }

      if (kIsWeb) {
        if (chats.chats.isEmpty) {
          Get.reload<ChatsService>(force: true);
          await chats.init();
        }

        if (cs.contacts.isEmpty) {
          await cs.refreshContacts();
        }
      }
    }
  }

  static Future<void> detectLocalhost({bool createSnackbar = false}) async {
    if (ss.settings.localhostPort.value == null || kIsWeb) {
      http.originOverride = null;
      return;
    }

    List<ConnectivityResult> status = await (Connectivity().checkConnectivity());
    if (!status.contains(ConnectivityResult.wifi) && !status.contains(ConnectivityResult.ethernet)) {
      http.originOverride = null;
      return;
    }

    final schemes = ['https', 'http'];

    try {
      await http.serverInfo().then((response) async {
        List<String> localIpv4s = ((response.data?['data']?['local_ipv4s'] ?? []) as List).cast<String>();
        List<String> localIpv6s = ((response.data?['data']?['local_ipv6s'] ?? []) as List).cast<String>();
        String? address;
        if (ss.settings.useLocalIpv6.value) {
          for (String ip in localIpv6s) {
            for (String scheme in schemes) {
              String addr = "$scheme://[$ip]:${ss.settings.localhostPort.value!}";
              try {
                Response response = await http.ping(customUrl: addr);
                if (response.data.toString().contains("pong")) {
                  address = addr;
                  break;
                }
              } catch (ex) {
                Logger.debug('Failed to connect to localhost addres: $addr');
              }
            }
            if (address != null) break;
          }
        }
        if (address == null) {
          for (String ip in localIpv4s) {
            for (String scheme in schemes) {
              String addr = "$scheme://$ip:${ss.settings.localhostPort.value!}";
              try {
                final response = await http.ping(customUrl: addr);
                if (response.data.toString().contains("pong")) {
                  address = addr;
                  break;
                }
              } catch (ex) {
                Logger.debug('Failed to connect to localhost addres: $addr');
              }
            }
            if (address != null) break;
          }
        }

        if (address != null) {
          Logger.debug('Localhost Detected. Connected to $address');
          if (createSnackbar) {
            showSnackbar('Localhost Detected', 'Connected to $address');
          }

          http.originOverride = address;
        } else {
          http.originOverride = null;
        }
      });
    } catch (_) {}

    if (http.originOverride != null) return;

    // This was moved from main.dart to here because this is the only place we use it.
    // This will also make an API call to a github file containing a mapping of MAC addresses
    // to vendor information. That info is used to display metadata about an ActiveHost found
    // on the network via a port scan. We don't want that API call to happen on first-boot, nor
    // do we need it to.
    await configureNetworkTools(fs.appDocDir.path, enableDebugging: kDebugMode);

    Logger.debug("Falling back to port scanning");
    final wifiIP = await NetworkInfo().getWifiIP();
    if (wifiIP != null) {
      final stream = HostScannerService.instance.scanDevicesForSinglePort(
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
              Response response = await http.ping(customUrl: addr);
              if (response.data.toString().contains("pong")) {
                address = addr;
                break;
              }
            } catch (ex) {
              Logger.debug('Failed to connect to localhost addres: $addr');
            }
          }
          if (address != null) break;
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
