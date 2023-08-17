import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:firebase_dart/implementation/pure_dart.dart';
import 'package:firebase_dart/src/firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' show DetailedApiRequestError;
import 'package:bluebubbles/models/models.dart';

DatabaseService fdb = Get.isRegistered<DatabaseService>() ? Get.find<DatabaseService>() : Get.put(DatabaseService());

class DatabaseService extends GetxService {
  @override
  void onInit() {
    super.onInit();
    if (kIsDesktop || kIsWeb) {
      FirebaseDart.setup(
        platform: Platform.web(
          currentUrl: Uri.base.toString(),
          isMobile: false,
          isOnline: true,
        ),
      );
    }
  }

  String? getClientId() {
    if (kIsWeb) return '500464701389-8trcdkcj7ni5l4dn6n7l795rhb1asnh3.apps.googleusercontent.com';
    if (kIsDesktop) return '500464701389-tqqvjqk03q7dotrvt1rug7g1flgn9rtg.apps.googleusercontent.com';
    return null;
  }

  /// Fetch the new server URL from the Firebase Database
  Future<String?> fetchNewUrl() async {
    // Make sure setup is complete and we have valid data
    if (!ss.settings.finishedSetup.value) return null;
    if (ss.fcmData.isNull) {
      Logger.error("Firebase Data was null!");
      return null;
    }

    try {
      String? url;
      Logger.info("Fetching new server URL from Firebase");
      // Use firebase_dart on web and desktop
      if (kIsWeb || kIsDesktop) {
        // Instantiate the FirebaseDatabase, and try to access the serverUrl field
        final defaultOptions = FirebaseOptions(
            apiKey: ss.fcmData.apiKey ?? '',
            appId: ss.fcmData.applicationID ?? '',
            messagingSenderId: '',
            projectId: ss.fcmData.projectID ?? '',
            databaseURL: ss.fcmData.firebaseURL,
        );

        late final FirebaseApp app;
        if (Firebase.apps.isEmpty) {
          app = await Firebase.initializeApp(options: defaultOptions);
        } else {
          app = Firebase.apps.first;
        }

        if (!isNullOrEmpty(ss.fcmData.firebaseURL)!) {
          final FirebaseDatabase db = FirebaseDatabase(app: app);
          final DatabaseReference ref = db.reference().child('config').child('serverUrl');

          final Event event = await ref.onValue.first;
          url = sanitizeServerAddress(address: event.snapshot.value);
        } else {
          final FirebaseFirestore db = FirebaseFirestore.instanceFor(app: app);
          try {
            final doc = await db.collection("server").doc("config").get();
            if (doc.data()?['serverUrl'] != null) {
              url = sanitizeServerAddress(address: doc.data()!['serverUrl']);
            }
          } catch (e) {
            if (e is DetailedApiRequestError && e.status == 403) {
              // This means the db url is probably wrong. Refresh it and try again
              http.fcmClient().then((response) async {
                Map<String, dynamic>? data = response.data["data"];
                print(data);
                if (!isNullOrEmpty(data)!) {
                  FCMData newData = FCMData.fromMap(data!);
                  ss.saveFCMData(newData);

                  final FirebaseFirestore db = FirebaseFirestore.instanceFor(app: app);
                  final doc = await db.collection("server").doc("config").get();
                  if (doc.data()?['serverUrl'] != null) {
                    url = sanitizeServerAddress(address: doc.data()!['serverUrl']);
                  }
                }
              });
            }
          }
        }
      } else {
        // First, try to auth with FCM with the current data
        Logger.info('Authenticating with FCM', tag: 'FCM-Auth');
        await mcs.invokeMethod('auth', ss.fcmData.toMap());
        url = sanitizeServerAddress(address: await mcs.invokeMethod("get-server-url"));
      }
      // Update the address of the copied settings
      ss.settings.serverAddress.value = url ?? ss.settings.serverAddress.value;
      await ss.saveSettings();
      return url;
    } catch (e, s) {
      Logger.error("Failed to fetch URL: $e\n${s.toString()}");
      return null;
    }
  }
}
