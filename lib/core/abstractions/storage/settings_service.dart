import 'package:bluebubbles/models/models.dart';
import '../../abstractions/service.dart';


abstract class SettingsService extends Service {
  @override
  bool required = true;

  Settings get config;

  @override
  Future<void> initAllPlatforms() async {
    await loadConfig();
  }

  Future<void> saveConfig([Settings? newSettings, bool updateDisplayMode = false]);

  Future<void> loadConfig();
}