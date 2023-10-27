import 'package:bluebubbles/core/services/services.dart';

import '../abstractions/service.dart';


abstract class UpdateService extends Service {
  @override
  List<Service> dependencies = [device];

  Future<void> checkForServerUpdate();

  Future<void> checkForClientUpdate();
}