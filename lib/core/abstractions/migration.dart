import 'package:bluebubbles/core/utilities/service_logger.dart';

abstract class Migration {
  String get name;

  String get description;

  int get version;

  late ServiceLogger log;

  Migration() {
    log = ServiceLogger(name);
  }

  Future<void> execute();
}