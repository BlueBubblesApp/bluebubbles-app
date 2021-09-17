import 'dart:async';

import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:firebase_dart/firebase_dart.dart';
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

  Future<FCMData> save() async {
    fcmDataBox.put(this);
    return this;
  }

  static void deleteFcmData() {
    prefs.remove('projectID');
    prefs.remove('storageBucket');
    prefs.remove('apiKey');
    prefs.remove('firebaseURL');
    prefs.remove('clientID');
    prefs.remove('applicationID');
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

  static Future<FCMData> getFCM() async {
    /*Database? db = await DBProvider.db.database;

    List<Map<String, dynamic>> result = (await db?.query("fcm")) ?? [];*/
    final result = fcmDataBox.getAll();
    if (result.isEmpty) return new FCMData(
      projectID: prefs.getString('projectID'),
      storageBucket: prefs.getString('storageBucket'),
      apiKey: prefs.getString('apiKey'),
      firebaseURL: prefs.getString('firebaseURL'),
      clientID: prefs.getString('clientID'),
      applicationID: prefs.getString('applicationID'),
    );
    return result.first;
  }

  Map<String, dynamic> toMap() => {
        "project_id": this.projectID,
        "storage_bucket": this.storageBucket,
        "api_key": this.apiKey,
        "firebase_url": this.firebaseURL,
        "client_id": this.clientID,
        "application_id": this.applicationID,
      };
  bool get isNull =>
      this.projectID == null ||
      this.storageBucket == null ||
      this.apiKey == null ||
      this.firebaseURL == null ||
      this.clientID == null ||
      this.applicationID == null;
}
