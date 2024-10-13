import 'dart:async';

/// Shim for NetworkInfo to allow for web compile
class HostScanner {
  /// Obtains the IPv4 address of the connected wifi network
  static Stream<ActiveHost> scanDevicesForSinglePort(
    String subnet,
    int port, {
      int firstHostId = 1,
      int lastHostId = 254,
      Duration timeout = const Duration(milliseconds: 2000),
      dynamic progressCallback,
      bool resultsInAddressAscendingOrder = true,
    }) {
    final StreamController<ActiveHost> activeHostsController = StreamController<ActiveHost>();
    return activeHostsController.stream;
  }
}

class ActiveHost {
  String address = "";
}