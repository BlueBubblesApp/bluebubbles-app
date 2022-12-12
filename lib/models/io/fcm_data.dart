import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
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

  FCMData save() {
    if (kIsWeb) return this;
    fcmDataBox.put(this);
    return this;
  }

  static void deleteFcmData() {
    fcmDataBox.removeAll();
    ss.prefs.remove('projectID');
    ss.prefs.remove('storageBucket');
    ss.prefs.remove('apiKey');
    ss.prefs.remove('firebaseURL');
    ss.prefs.remove('clientID');
    ss.prefs.remove('applicationID');
  }

  static FCMData getFCM() {
    final result = fcmDataBox.getAll();
    if (result.isEmpty) {
      return FCMData(
        projectID: ss.prefs.getString('projectID'),
        storageBucket: ss.prefs.getString('storageBucket'),
        apiKey: ss.prefs.getString('apiKey'),
        firebaseURL: ss.prefs.getString('firebaseURL'),
        clientID: ss.prefs.getString('clientID'),
        applicationID: ss.prefs.getString('applicationID'),
      );
    }
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
      projectID == null ||
      storageBucket == null ||
      apiKey == null ||
      firebaseURL == null ||
      clientID == null ||
      applicationID == null;
}
