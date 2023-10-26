import 'package:bluebubbles/core/logging/named_logger.dart';

abstract class Migration {
  String get name;

  String get description;

  int get version;

  late NamedLogger log;

  Migration() {
    log = NamedLogger(name);
  }

  Future<void> execute();
}