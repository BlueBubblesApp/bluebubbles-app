import 'package:bluebubbles/core/services/services.dart';

import '../abstractions/service.dart';


abstract class DeviceService extends Service {
  @override
  bool required = true;

  bool get supportsLocalAuth;

  bool installedFromStore = true;

  @override
  List<Service> dependencies = [db, settings];

  Future<void> setupLaunchAtStartup();
}