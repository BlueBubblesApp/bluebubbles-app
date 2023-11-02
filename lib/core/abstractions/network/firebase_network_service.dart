
abstract class FirebaseNetworkService {
  Future<dynamic> getProjects(String accessToken);
  Future<dynamic> getGoogleInfo(String accessToken);
  Future<dynamic> getServerUrlRTDB(String rtdb, String accessToken);
  Future<dynamic> getServerUrlFirestore(String project, String accessToken);
  Future<dynamic> setRestartDateFirestore(String project);
}