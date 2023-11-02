import 'package:bluebubbles/core/abstractions/storage/migration.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';

class ObjectBoxSaveFcmDataMigration extends Migration {
  @override
  String name = "ObjectBox-SaveFcmData";

  @override
  String description = "Saves the FCM data to the shared preferences for use in the Tasker integration.";

  @override
  int version = 4;

  @override
  Future<void> execute() {
    ss.getFcmData();
    ss.fcmData.save();

    return Future.value();
  }
}