import 'package:bluebubbles/core/abstractions/shared_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RxSharedPrefsService extends SharedPreferenceService {
  @override
  final String name = "Rx Shared Prefs Service";

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
  