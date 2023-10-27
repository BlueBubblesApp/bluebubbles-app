import '../abstractions/service.dart';


abstract class DeviceService extends Service {
  @override
  bool required = true;

  bool get supportsLocalAuth;

  bool installedFromStore = true;

  Future<void> setupLaunchAtStartup();
}