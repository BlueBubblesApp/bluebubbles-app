import 'dart:async';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart'
    if (dart.library.html) 'package:bluebubbles/models/html/network_tools.dart';

class NetworkTasks {
  static Future<void>? _configureNetworkToolsFuture;

  /// Deduplicates concurrent detectLocalhost() calls — callers share one result.
  static Future<void>? _detectLocalhostFuture;

  /// Timestamp of the last completed subnet port scan (Phase 2). Used to skip
  /// repeated full-subnet scans on rapid app resumes when the server is offline.
  static DateTime? _lastSubnetScanTime;

  /// Minimum gap between Phase-2 subnet scans. Phase 1 (server-reported IPs)
  /// always runs; only the expensive 255-address fallback is throttled.
  static const Duration _subnetScanThrottle = Duration(minutes: 2);

  /// Isolates that should receive [HttpSvc.originOverride] syncs.
  /// Populated via [registerIsolate] — no hardcoded types here.
  static final List<GlobalIsolate> _isolateRegistry = [];

  static Future<void> onConnect() async {
    if (!SettingsSvc.settings.finishedSetup.value) return;
    Logger.info('[NetworkTasks] Handling onConnect tasks. Finished Setup: ${SettingsSvc.settings.finishedSetup.value}');

    if (kIsWeb) {
      if (ChatsSvc.isEmpty) {
        ChatsSvc.reset();
        await ChatsSvc.init();
      }
    }

    // When we re-connect, try an incremental sync.
    // The sync function has a guard based on time to ensure that it doesn't
    // get invoked multiple times in quick succession.
    unawaited(SyncSvc.startIncrementalSync());
  }

  static Future<void> detectLocalhost({bool createSnackbar = false}) {
    // Deduplicate: if already running, all callers share the same future.
    _detectLocalhostFuture ??=
        _detectLocalhostImpl(createSnackbar: createSnackbar).whenComplete(() => _detectLocalhostFuture = null);
    return _detectLocalhostFuture!;
  }

  static Future<void> _detectLocalhostImpl({bool createSnackbar = false}) async {
    final port = SettingsSvc.settings.localhostPort.value;
    if (port == null || kIsWeb) {
      setOriginOverride(null);
      return;
    }

    final status = await Connectivity().checkConnectivity();
    if (!status.contains(ConnectivityResult.wifi) && !status.contains(ConnectivityResult.ethernet)) {
      setOriginOverride(null);
      return;
    }

    // Reset any stale local override so serverInfo() queries the remote server
    // for fresh local IPs, and so the port-scan fallback isn't skipped if the
    // serverInfo call fails.
    setOriginOverride(null);

    // Phase 1: try the known local IPs reported by the server.
    try {
      final response = await HttpSvc.server.info();
      final data = response.data?['data'];
      final localIpv4s = ((data?['local_ipv4s'] ?? []) as List).cast<String>();
      final localIpv6s = ((data?['local_ipv6s'] ?? []) as List).cast<String>();

      // IPv6 addresses need brackets in URLs: [::1]
      final candidates = [
        if (SettingsSvc.settings.useLocalIpv6.value) ...localIpv6s.map((ip) => '[$ip]'),
        ...localIpv4s,
      ];

      setOriginOverride(await _probeAddresses(candidates, port));
    } catch (e) {
      Logger.warn('Could not fetch server info for localhost detection: $e', tag: 'NetworkTasks');
    }

    if (HttpSvc.originOverride != null) {
      Logger.debug('Localhost detected at ${HttpSvc.originOverride}', tag: 'NetworkTasks');
      if (createSnackbar) {
        showToast('Connected to ${HttpSvc.originOverride}');
      }
      return;
    }

    // Phase 2: fall back to a subnet port scan.
    // configureNetworkTools is cached because it makes an external API call to
    // fetch MAC vendor data. We don't want that on first boot.

    // Throttle: skip the full subnet scan if one was run recently. The scan is
    // expensive (probes all 255 addresses) and firing it on every app resume
    // when the server is unreachable would drain battery unnecessarily.
    final now = DateTime.now();
    if (_lastSubnetScanTime != null && now.difference(_lastSubnetScanTime!) < _subnetScanThrottle) {
      Logger.debug(
        'Skipping subnet scan — last scan was ${now.difference(_lastSubnetScanTime!).inSeconds}s ago (throttle: ${_subnetScanThrottle.inMinutes}m)',
        tag: 'NetworkTasks',
      );
      return;
    }
    _lastSubnetScanTime = now;
    _configureNetworkToolsFuture ??= configureNetworkTools(FilesystemSvc.appDocDir.path, enableDebugging: kDebugMode);
    await _configureNetworkToolsFuture;

    Logger.debug('Falling back to port scanning', tag: 'NetworkTasks');
    final wifiIP = await NetworkInfo().getWifiIP();
    if (wifiIP == null) {
      setOriginOverride(null);
      return;
    }

    final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
    final hosts = <ActiveHost>{};
    final completer = Completer<void>();
    HostScannerService.instance.scanDevicesForSinglePort(subnet, int.parse(port)).listen(
      (host) => hosts.add(host),
      onDone: () async {
        setOriginOverride(await _probeAddresses(hosts.map((h) => h.address).toList(), port));
        if (createSnackbar && HttpSvc.originOverride != null) {
          showToast('Connected to ${HttpSvc.originOverride}');
        }
        completer.complete();
      },
      onError: (_, _) {
        setOriginOverride(null);
        completer.complete();
      },
    );
    await completer.future;
  }

  /// Sets [HttpSvc.originOverride] and syncs the new value to registered isolates.
  static void setOriginOverride(String? originOverride) {
    HttpSvc.originOverride = originOverride;
    syncOriginOverrideToIsolate();
  }

  /// Broadcasts the current [HttpSvc.originOverride] to [isolate], or — when
  /// called with no argument — to every registered isolate that is currently
  /// running (dormant isolates with idleTimeout=zero are skipped).
  static void syncOriginOverrideToIsolate([GlobalIsolate? isolate]) {
    if (kIsWeb) return;
    if (isolate != null) {
      isolate.broadcast(IsolateRequestType.setOriginOverride, HttpSvc.originOverride);
      return;
    }
    for (final candidate in _isolateRegistry) {
      if (candidate.isRunning) {
        candidate.broadcast(IsolateRequestType.setOriginOverride, HttpSvc.originOverride);
      }
    }
  }

  /// Registers [isolate] to receive [HttpSvc.originOverride] syncs.
  /// Also wires up a started callback so the override is re-synced
  /// automatically whenever the isolate (re)starts after an idle timeout.
  static void registerIsolate(GlobalIsolate isolate) {
    _isolateRegistry.add(isolate);
    isolate.addStartedCallback(() async {
      isolate.broadcast(IsolateRequestType.setOriginOverride, HttpSvc.originOverride);
    });
  }

  /// Probes [ips] on [port] with https then http, returning the first address
  /// that responds with "pong", or null if none respond.
  ///
  /// IPv6 addresses must already be bracket-formatted, e.g. `[::1]`.
  static Future<String?> _probeAddresses(List<String> ips, String port) async {
    for (final ip in ips) {
      for (final scheme in ['https', 'http']) {
        final addr = '$scheme://$ip:$port';
        try {
          final response = await HttpSvc.server.ping(customUrl: addr);
          if (response.data.toString().contains('pong')) return addr;
        } catch (_) {
          Logger.debug('Failed to connect to local address: $addr', tag: 'NetworkTasks');
        }
      }
    }
    return null;
  }
}
