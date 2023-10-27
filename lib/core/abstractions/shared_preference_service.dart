import 'package:shared_preferences/shared_preferences.dart';

import '../abstractions/service.dart';


abstract class SharedPreferenceService extends Service {
  @override
  bool required = true;

  SharedPreferences get config;
}