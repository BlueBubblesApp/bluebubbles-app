import 'package:bluebubbles/core/abstractions/database_service.dart';
import 'package:bluebubbles/core/abstractions/device_service.dart';
import 'package:bluebubbles/core/abstractions/server_service.dart';
import 'package:bluebubbles/core/abstractions/settings_service.dart';
import 'package:bluebubbles/core/services/rx/rx_device_service.dart';
import 'package:bluebubbles/core/services/rx/rx_server_service.dart';
import 'package:bluebubbles/core/services/rx/rx_settings_service.dart';
import 'package:bluebubbles/core/services/objectbox_database_service.dart';
import 'package:get/get.dart';

DatabaseService db = Get.isRegistered<ObjectBoxDatabaseService>() ? Get.find<ObjectBoxDatabaseService>() : Get.put(ObjectBoxDatabaseService());
SettingsService settings = Get.isRegistered<RxSettingsService>() ? Get.find<RxSettingsService>() : Get.put(RxSettingsService());
ServerService server = Get.isRegistered<RxServerService>() ? Get.find<RxServerService>() : Get.put(RxServerService());
DeviceService device = Get.isRegistered<RxDeviceService>() ? Get.find<RxDeviceService>() : Get.put(RxDeviceService());