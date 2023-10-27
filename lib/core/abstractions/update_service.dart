import '../abstractions/service.dart';


abstract class UpdateService extends Service {
  Future<void> checkForServerUpdate();

  Future<void> checkForClientUpdate();
}