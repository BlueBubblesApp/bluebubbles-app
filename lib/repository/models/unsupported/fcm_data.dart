import 'dart:async';

import 'package:bluebubbles/repository/models/config_entry.dart';

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

  factory FCMData.fromMap(Map<String, dynamic> json) => throw Exception("Unsupported Platform");

  factory FCMData.fromConfigEntries(List<ConfigEntry> entries) => throw Exception("Unsupported Platform");

  FCMData save() => throw Exception("Unsupported Platform");

  static void deleteFcmData() => throw Exception("Unsupported Platform");

  static Future<void> initializeFirebase(FCMData data) async => throw Exception("Unsupported Platform");

  static FCMData getFCM() => throw Exception("Unsupported Platform");

  Map<String, dynamic> toMap() => throw Exception("Unsupported Platform");

  bool get isNull => throw Exception("Unsupported Platform");
}
