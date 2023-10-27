import 'package:bluebubbles/core/abstractions/server_service.dart';
import 'package:bluebubbles/core/abstractions/service.dart';
import 'package:bluebubbles/core/lib/definitions/rx_server_details.dart';
import 'package:bluebubbles/core/services/services.dart';
import 'package:bluebubbles/services/network/http_service.dart';

class DefaultServerService extends ServerService {
  @override
  final String name = "Default Server Service";

  @override
  final int version = 1;

  @override
  List<Service> dependencies = [settings, prefs];

  final RxServerDetails details = RxServerDetails();

  int get macOsMajorVersion => prefs.config.getInt("macos-version") ?? 11;

  int get macOsMinorVersion => prefs.config.getInt("macos-minor-version") ?? 11;

  @override
  bool get isMinSierra => macOsMajorVersion >= 10 && macOsMinorVersion >= 13;

  @override
  bool get isMinMojave => macOsMajorVersion >= 10 && macOsMinorVersion >= 15;

  @override
  bool get isMinCatalina => macOsMajorVersion >= 10 && macOsMinorVersion >= 15;
  
  @override
  bool get isMinBigSur => macOsMajorVersion >= 11;
  
  @override
  bool get isMinMonterey => macOsMajorVersion >= 12;
  
  @override
  bool get isMinVentura => macOsMajorVersion >= 13;

  @override
  bool get isMinSonoma => macOsMajorVersion >= 14;

  @override
  bool get canCreateGroupChats {
    bool isMin_1_8_0 = details.versionCode.value != null && details.versionCode.value! >= 268;
    bool papiEnabled = settings.config.enablePrivateAPI.value;
    return (isMin_1_8_0 && papiEnabled) || !server.isMinBigSur;
  }

  @override
  Future<void> refreshDetails() async {
    final response = await http.serverInfo();
    if (response.statusCode != 200) {
      throw Exception("Failed to get server info! Response Data: ${response.data.toString()}");
    }

    details.loadFromMap(response.data['data']);
  }
}
  