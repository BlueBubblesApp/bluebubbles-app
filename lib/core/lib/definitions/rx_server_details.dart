import 'package:bluebubbles/core/services/services.dart';
import 'package:get/get.dart';

class RxServerDetails {
  final iCloudAccount = Rx<String?>(null);

  final osMajorVersion = Rx<int?>(null);

  final osMinorVersion = Rx<int?>(null);

  final versionCode = Rx<int?>(null);

  static _isValidString(dynamic value) => value != null && value is String && value.isNotEmpty;
  
  static _isValidInt(dynamic value) => value != null && value is int;

  Future<void> saveToDevice() async {
    if (osMajorVersion.value != null) {
      await prefs.config.setInt('macos-version', osMajorVersion.value!);
    }

    if (osMinorVersion.value != null) {
      await prefs.config.setInt('macos-minor-version', osMinorVersion.value!);
    }

    if (versionCode.value != null) {
      await prefs.config.setInt('server-version-code', osMinorVersion.value!);
    }

    if (iCloudAccount.value != null) {
      settings.config.iCloudAccount.value = iCloudAccount.value!;
      settings.config.save();
    }
  }

  void loadFromMap(Map<String, dynamic> data) {
    loadInto(this, data);
  }

  static loadInto(RxServerDetails details, Map<String, dynamic> data) {
    if (_isValidString(['detected_icloud'])) {
      details.iCloudAccount.value ??= data['detected_icloud'];
    }

    final osMajorVersion = int.tryParse(data['os_version'].split(".")[0]);
    final osMinorVersion = int.tryParse(data['os_version'].split(".")[1]);
    if (_isValidInt(osMajorVersion)) {
      details.osMajorVersion.value ??= osMajorVersion;
    }

    if (_isValidInt(osMinorVersion)) {
      details.osMinorVersion.value ??= osMinorVersion;
    }
  }

  static RxServerDetails fromMap(Map<String, dynamic> data) {
    RxServerDetails serverDetails = RxServerDetails();
    loadInto(serverDetails, data);
    return serverDetails;
  }
}