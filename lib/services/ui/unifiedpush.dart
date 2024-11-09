import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';

UnifiedPushPanelRefresh upr = Get.isRegistered<UnifiedPushPanelRefresh>()
    ? Get.find<UnifiedPushPanelRefresh>()
    : Get.put(UnifiedPushPanelRefresh());

class UnifiedPushPanelRefresh extends GetxService {
  var enabled = ss.settings.enableUnifiedPush.value.obs;
  var endpoint = ss.settings.endpointUnifiedPush.value.obs;

  void update(String newEndpoint) {
    endpoint.value = newEndpoint;
    enabled.value = newEndpoint != "";
    ss.settings.endpointUnifiedPush.value = newEndpoint;
    ss.settings.enableUnifiedPush.value = enabled.value;
    ss.saveSettings();
  }
}
