import 'package:bluebubbles/core/abstractions/network/firebase_network_service.dart';
import 'package:bluebubbles/core/services/network/dio/dio_network_service.dart';


class DioFirebaseNetworkService implements FirebaseNetworkService {

  @override
  bool isAvailable = true;

  DioNetworkService network;

  DioFirebaseNetworkService(this.network);
  
  @override
  Future getGoogleInfo(String accessToken) async {
    return network.requestWrapper(() async {
      final response = await network.dio.get(
        "https://www.googleapis.com/oauth2/v1/userinfo",
        queryParameters: {
          "access_token": accessToken
        }
      );

      return network.raiseForStatus(response);
    }, checkOrigin: false);
  }
  
  @override
  Future getProjects(String accessToken) async {
    return network.requestWrapper(() async {
      final response = await network.dio.get(
        "https://firebase.googleapis.com/v1beta1/projects",
        queryParameters: {
          "access_token": accessToken
        }
      );

      return network.raiseForStatus(response);
    }, checkOrigin: false);
  }
  
  @override
  Future getServerUrlFirestore(String project, String accessToken) async {
    return network.requestWrapper(() async {
      final response = await network.dio.get(
        "https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents/server/config",
        queryParameters: {
          "access_token": accessToken,
        }
      );

      return network.raiseForStatus(response);
    }, checkOrigin: false);
  }
  
  @override
  Future getServerUrlRTDB(String rtdb, String accessToken) async {
    return network.requestWrapper(() async {
      final response = await network.dio.get(
        "https://$rtdb.firebaseio.com/config.json",
        queryParameters: {
          "token": accessToken
        }
      );

      return network.raiseForStatus(response);
    }, checkOrigin: false);
  }
  
  @override
  Future setRestartDateFirestore(String project) async {
    return network.requestWrapper(() async {
      final response = await network.dio.patch(
        "https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents/server/commands?updateMask.fieldPaths=nextRestart",
        data: {
          "fields": {
            "nextRestart": {
              "integerValue": DateTime.now().toUtc().millisecondsSinceEpoch
            }
          }
        }
      );

      return network.raiseForStatus(response);
    }, checkOrigin: false);
  }
}