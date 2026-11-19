import 'package:bluebubbles/helpers/types/helpers/misc_helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

/// Take the passed [address] or serverAddress from Settings
/// and sanitize it, making sure it includes an http schema
String? sanitizeServerAddress({String? address}) {
  String serverAddress = address ?? HttpSvc.origin;

  String sanitized = serverAddress.replaceAll('"', "").trim();
  if (sanitized.isEmpty) return null;

  Uri? uri = Uri.tryParse(sanitized);
  if (uri?.scheme.isEmpty ?? false) {
    if (sanitized.contains("ngrok.io") || sanitized.contains("trycloudflare.com") || sanitized.contains("zrok.io")) {
      uri = Uri.tryParse("https://$sanitized");
    } else {
      uri = Uri.tryParse("http://$sanitized");
    }
  }

  return uri.toString();
}

bool isValidServerAddress(String address) {
  final sanitized = sanitizeServerAddress(address: address);
  if (sanitized == null) return false;

  final uri = Uri.tryParse(sanitized);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;

  return true;
}

Future<int> getOrCreateUniqueId() async {
  int uniqueId = SettingsSvc.settings.firstFcmRegisterDate.value;
  if (uniqueId == 0) {
    uniqueId = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    SettingsSvc.settings.firstFcmRegisterDate.value = uniqueId;
    await SettingsSvc.settings.saveOneAsync('firstFcmRegisterDate');
  }

  return uniqueId;
}

/// This phone's ANDROID_ID, which unlike [getOrCreateUniqueId] survives a reinstall. Android only.
///
/// It is not permanent: Android 8+ scopes it to the app's signing key and the Android user, and a factory reset
/// changes it. Switching between differently signed builds (e.g. a GitHub APK and the Play build) therefore gives a
/// new id, and contacts uploaded under the old one stay on the server.
///
/// Falls back to [getOrCreateUniqueId] on the rare device that reports no ANDROID_ID.
Future<String> getAndroidId() async {
  if (kIsWeb || kIsDesktop) throw UnsupportedError('getAndroidId is Android only');
  final id = await MethodChannelSvc.invokeMethod('get-android-id') as String?;
  if (id != null && id.isNotEmpty) return id;
  Logger.warn('Device reports no ANDROID_ID; using the install id instead', tag: 'getAndroidId');
  return (await getOrCreateUniqueId()).toString();
}

Future<String> getDeviceName() async {
  String deviceName = "bluebubbles-client";

  try {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    List<String> items = [];

    // We need a unique identifier to be generated once per installation.
    // Device Info Plus doesn't provide us with an idempotent identifier,
    // so we'll have to generate one ourselves, and store it for future use.
    int uniqueId = await getOrCreateUniqueId();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      items.addAll([androidInfo.brand, androidInfo.model, uniqueId.toString()]);
    } else if (kIsWeb) {
      WebBrowserInfo webInfo = await deviceInfo.webBrowserInfo;
      items.addAll([webInfo.browserName.name, webInfo.platform!]);
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
      items.addAll([windowsInfo.computerName]);
    } else if (Platform.isLinux) {
      LinuxDeviceInfo linuxInfo = await deviceInfo.linuxInfo;
      items.addAll([linuxInfo.prettyName]);
    }

    if (items.isNotEmpty) {
      deviceName = items.join("_").toLowerCase().replaceAll(' ', '_');
    }
  } catch (ex, stack) {
    Logger.error("Failed to get device name! Defaulting to 'bluebubbles-client'", error: ex, trace: stack);
  }

  return deviceName;
}
