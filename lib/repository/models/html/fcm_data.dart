import 'dart:async';

import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/repository/models/config_entry.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:firebase_dart/firebase_dart.dart';

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

  factory FCMData.fromConfigEntries(List<ConfigEntry> entries) {
    FCMData data = FCMData();
    for (ConfigEntry entry in entries) {
      if (entry.name == "projectID") {
        data.projectID = entry.value;
      } else if (entry.name == "storageBucket") {
        data.storageBucket = entry.value;
      } else if (entry.name == "apiKey") {
        data.apiKey = entry.value;
      } else if (entry.name == "firebaseURL") {
        data.firebaseURL = entry.value;
      } else if (entry.name == "clientID") {
        data.clientID = entry.value;
      } else if (entry.name == "applicationID") {
        data.applicationID = entry.value;
      }
    }
    return data;
  }

  FCMData save() {
    if (isNull) return this;
    ss.prefs.setString('projectID', projectID!);
    ss.prefs.setString('storageBucket', storageBucket!);
    ss.prefs.setString('apiKey', apiKey!);
    ss.prefs.setString('firebaseURL', firebaseURL!);
    ss.prefs.setString('clientID', clientID!);
    ss.prefs.setString('applicationID', applicationID!);
    return this;
  }

  static void deleteFcmData() {
    ss.prefs.remove('projectID');
    ss.prefs.remove('storageBucket');
    ss.prefs.remove('apiKey');
    ss.prefs.remove('firebaseURL');
    ss.prefs.remove('clientID');
    ss.prefs.remove('applicationID');
  }

  static Future<void> initializeFirebase(FCMData data) async {
    var options = FirebaseOptions(
      appId: data.applicationID!,
      apiKey: data.apiKey!,
      projectId: data.projectID!,
      storageBucket: data.storageBucket,
      databaseURL: data.firebaseURL,
      messagingSenderId: data.clientID,
    );
    app = await Firebase.initializeApp(options: options);
  }

  static FCMData getFCM() {
    return FCMData(
      projectID: ss.prefs.getString('projectID'),
      storageBucket: ss.prefs.getString('storageBucket'),
      apiKey: ss.prefs.getString('apiKey'),
      firebaseURL: ss.prefs.getString('firebaseURL'),
      clientID: ss.prefs.getString('clientID'),
      applicationID: ss.prefs.getString('applicationID'),
    );
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
