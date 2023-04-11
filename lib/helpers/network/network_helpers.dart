import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

/// Take the passed [address] or serverAddress from Settings
/// and sanitize it, making sure it includes an http schema
String? sanitizeServerAddress({String? address}) {
  String serverAddress = address ?? http.origin;

  String sanitized = serverAddress.replaceAll('"', "").trim();
  if (sanitized.isEmpty) return null;

  Uri? uri = Uri.tryParse(sanitized);
  if (uri?.scheme.isEmpty ?? false) {
    if (sanitized.contains("ngrok.io") || sanitized.contains("trycloudflare.com")) {
      uri = Uri.tryParse("https://$sanitized");
    } else {
      uri = Uri.tryParse("http://$sanitized");
    }
  }

  return uri.toString();
}

Future<String> getDeviceName() async {
  String deviceName = "bluebubbles-client";

  try {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    List<String> items = [];

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      items.addAll([androidInfo.brand, androidInfo.model, androidInfo.id]);
    } else if (kIsWeb) {
      WebBrowserInfo webInfo = await deviceInfo.webBrowserInfo;
      items.addAll([describeEnum(webInfo.browserName), webInfo.platform!]);
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
      items.addAll([windowsInfo.computerName]);
    } else if (Platform.isLinux) {
      LinuxDeviceInfo linuxInfo = await deviceInfo.linuxInfo;
      items.addAll([linuxInfo.prettyName]);
    }

    if (items.isNotEmpty) {
      deviceName = items.join("_").toLowerCase();
    }
  } catch (ex) {
    Logger.error("Failed to get device name! Defaulting to 'bluebubbles-client'");
    Logger.error(ex.toString());
  }

  return deviceName;
}