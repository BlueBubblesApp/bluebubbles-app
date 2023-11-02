import 'package:bluebubbles/core/abstractions/storage/shared_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DefaultSharedPrefsService extends SharedPreferenceService {
  @override
  final String name = "Default Shared Prefs Service";

  @override
  final int version = 1;

  @override
  bool get required => true;

  @override
  late SharedPreferences config;

  @override
  Future<void> initAllPlatforms() async {
    config = await SharedPreferences.getInstance();
    return Future.value();
  }

  Future<void> reset() async {
    if (!hasInitialized) {
      await init();
    }

    await config.clear();
  }
}
  