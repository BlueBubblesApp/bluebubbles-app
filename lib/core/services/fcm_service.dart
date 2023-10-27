import 'package:bluebubbles/core/abstractions/service.dart';
import 'package:bluebubbles/core/services/services.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/foundation.dart';

class FCMService extends Service {
  @override
  String get name => "FCM Service";

  @override
  int version = 1;

  @override
  bool required = false;

  @override
  List<Service> dependencies = [prefs];

  final FCMData fcmData = FCMData();

  load(FCMData other) {
    fcmData.projectID = other.projectID;
    fcmData.storageBucket = other.storageBucket;
    fcmData.apiKey = other.apiKey;
    fcmData.firebaseURL = other.firebaseURL;
    fcmData.clientID = other.clientID;
    fcmData.applicationID = other.applicationID;
  }

  @override
  Future<void> initAllPlatforms() async {
    if (kIsWeb) return;

    final result = db.fcm.getAll();
    if (result.isNotEmpty) {
      load(result.first);
    }

    return Future.value();
  }

  @override
  Future<void> stop() async {
    return Future.value();
  }

  Future<void> delete() async {
    db.fcm.removeAll();
    await prefs.config.remove('projectID');
    await prefs.config.remove('storageBucket');
    await prefs.config.remove('apiKey');
    await prefs.config.remove('firebaseURL');
    await prefs.config.remove('clientID');
    await prefs.config.remove('applicationID');
    fcmData.clear();
  }

  Future<void> saveAll() async {
    await saveToDb();
    await saveToSharedPrefs();
  }

  Future<void> saveToDb() async {
    if (kIsWeb) return;
    List<FCMData> data = db.fcm.getAll();
    if (data.length > 1) data.removeRange(1, data.length); // These were being ignored anyway
    fcmData.id = !db.fcm.isEmpty() ? data.first.id : null;
    db.fcm.put(fcmData);
  }

  Future<void> saveToSharedPrefs() async {
    if (kIsWeb) return;
    if (fcmData.projectID != null) {
      await prefs.config.setString('projectID', fcmData.projectID!);
    } else {
      await prefs.config.remove('projectID');
    }
    if (fcmData.storageBucket != null) {
      await prefs.config.setString('storageBucket', fcmData.storageBucket!);
    } else {
      await prefs.config.remove('storageBucket');
    }
    if (fcmData.apiKey != null) {
      await prefs.config.setString('apiKey', fcmData.apiKey!);
    } else {
      await prefs.config.remove('apiKey');
    }
    if (fcmData.firebaseURL != null) {
      await prefs.config.setString('firebaseURL', fcmData.firebaseURL!);
    } else {
      await prefs.config.remove('firebaseURL');
    }
    if (fcmData.clientID != null) {
      await prefs.config.setString('clientID', fcmData.clientID!);
    } else {
      await prefs.config.remove('clientID');
    }
    if (fcmData.applicationID != null) {
      await prefs.config.setString('applicationID', fcmData.applicationID!);
    } else {
      await prefs.config.remove('applicationID');
    }
  }
}