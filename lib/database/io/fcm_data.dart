import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/generated/objectbox.g.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class FCMData {
  int? id;
  String? projectID;
  String? storageBucket;
  String? apiKey;
  String? firebaseURL;
  String? clientID;
  String? applicationID;

  FCMData({
    this.id,
    this.projectID,
    this.storageBucket,
    this.apiKey,
    this.firebaseURL,
    this.clientID,
    this.applicationID,
  });

  factory FCMData.fromMap(Map<String, dynamic> json) {
    Map<String, dynamic> projectInfo = json["project_info"];
    Map<String, dynamic> client = json["client"][0];
    String clientID = client["oauth_client"][0]["client_id"];
    return FCMData(
      projectID: projectInfo["project_id"],
      storageBucket: projectInfo["storage_bucket"],
      apiKey: client["api_key"][0]["current_key"],
      firebaseURL: projectInfo["firebase_url"],
      clientID: clientID.contains("-") ? clientID.substring(0, clientID.indexOf("-")) : clientID,
      applicationID: client["client_info"]["mobilesdk_app_id"],
    );
  }

  Future<FCMData> save({bool wait = false}) async {
    if (kIsWeb) return this;
    List<FCMData> data = Database.fcmData.getAll();
    if (data.length > 1) data.removeRange(1, data.length); // These were being ignored anyway
    id = !Database.fcmData.isEmpty() ? data.first.id : null;
    Database.fcmData.put(this);
    final future = Future(() async {
      await PrefsSvc.firebase.saveConfig(
        projectID: projectID,
        storageBucket: storageBucket,
        apiKey: apiKey,
        firebaseURL: firebaseURL,
        clientID: clientID,
        applicationID: applicationID,
      );
    });

    if (wait) {
      await future;
    }

    SettingsSvc.fcmData = this;
    return this;
  }

  static Future<void> deleteFcmData() async {
    Database.fcmData.removeAll();
    await PrefsSvc.firebase.clearConfig();
    SettingsSvc.fcmData = FCMData();
  }

  static FCMData getFCM() {
    // ObjectBox is the durable source of truth for FCM configuration. When it's empty the
    // config isn't present, so return an unconfigured FCMData rather than rebuilding it from
    // the SharedPreferences mirror. That mirror can lag behind the database (e.g. a clear
    // whose async prefs write didn't flush before the app exited), and reading it here would
    // otherwise resurrect a configuration the user already cleared.
    final result = Database.fcmData.getAll();
    if (result.isEmpty) return FCMData();
    return result.first;
  }

  Map<String, dynamic> toMap() => {
        "project_id": projectID,
        "storage_bucket": storageBucket,
        "api_key": apiKey,
        "firebase_url": firebaseURL,
        "client_id": clientID,
        "application_id": applicationID,
      };

  bool get isNull =>
      projectID == null || storageBucket == null || apiKey == null || clientID == null || applicationID == null;
}
