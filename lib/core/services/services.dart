import 'package:bluebubbles/core/abstractions/database_service.dart';
import 'package:bluebubbles/core/services/objectbox_database_service.dart';
import 'package:get/get.dart';

DatabaseService db = Get.isRegistered<ObjectBoxDatabaseService>() ? Get.find<ObjectBoxDatabaseService>() : Get.put(ObjectBoxDatabaseService());
