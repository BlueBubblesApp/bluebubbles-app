import 'package:bluebubbles/database/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fix(double latitude, double longitude, int timeStamp, {String positionType = 'Wifi'}) => {
  'latitude': latitude,
  'longitude': longitude,
  'timeStamp': timeStamp,
  'positionType': positionType,
};

FindMyDevice device({Map<String, dynamic>? location, Map<String, dynamic>? crowdSourced}) => FindMyDevice.fromJson({
  'id': 'device',
  'name': 'Device',
  'location': location,
  'crowdSourcedLocation': crowdSourced,
});

void main() {
  group('FindMyDevice location', () {
    test('uses the crowd-sourced fix when Apple reports no primary location', () {
      final result = device(crowdSourced: fix(32.5, -96.5, 1000, positionType: 'crowdsourced'));

      expect(result.location?.latitude, 32.5);
      expect(result.location?.longitude, -96.5);
      expect(result.location?.positionType, 'crowdsourced');
    });

    test('keeps the primary location when it is newer than the crowd-sourced fix', () {
      final result = device(location: fix(32.0, -96.0, 2000), crowdSourced: fix(33.0, -97.0, 1000));

      expect(result.location?.latitude, 32.0);
    });

    test('uses the crowd-sourced fix when it is newer than the primary location', () {
      final result = device(location: fix(32.0, -96.0, 1000), crowdSourced: fix(33.0, -97.0, 2000));

      expect(result.location?.latitude, 33.0);
    });

    test('ignores a crowd-sourced fix without usable coordinates', () {
      final result = device(location: fix(32.0, -96.0, 1000), crowdSourced: fix(0, 0, 2000));

      expect(result.location?.latitude, 32.0);
    });

    test('has no location when neither fix is usable', () {
      expect(device(crowdSourced: fix(0, 0, 2000)).location, isNull);
    });
  });
}
