// ignore_for_file: deprecated_member_use_from_same_package
import 'package:bluebubbles/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

/// Each deprecated accessor must resolve to the *same instance* as its
/// replacement. A wrong target would still compile whenever two services share
/// a supertype, so identity is the thing worth asserting.
void main() {
  setUp(() => GetIt.I.reset());
  tearDown(() => GetIt.I.reset());

  test('ss resolves to the same instance as SettingsSvc', () {
    GetIt.I.registerSingleton<SettingsService>(SettingsService());
    expect(identical(ss, SettingsSvc), isTrue);
  });

  test('http resolves to the same instance as HttpSvc', () {
    GetIt.I.registerSingleton<HttpService>(HttpService());
    expect(identical(http, HttpSvc), isTrue);
  });

  test('an unregistered service still throws through the alias', () {
    expect(() => ss, throwsA(anything), reason: 'alias must not mask missing registration');
  });
}
