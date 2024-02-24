import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';

HealthService healthService = Get.isRegistered<HealthService>() ? Get.find<HealthService>() : Get.put(HealthService());

class HealthService extends GetxService {
  Future<void> setBackgroundPingingState(bool enabled) async {
    if (enabled) {
      await enableBackgroundPinging();
    } else {
      await disableBackgroundPinging();
    }
  }
  
  Future<void> enableBackgroundPinging() async {
    await mcs.invokeMethod("health-check-setup", {"enabled": true});
  }

  Future<void> disableBackgroundPinging() async {
    await mcs.invokeMethod("health-check-setup", {"enabled": false});
  }
}