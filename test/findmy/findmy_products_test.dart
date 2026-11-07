import 'package:bluebubbles/app/layouts/findmy/widgets/findmy_items_tab_view.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter_test/flutter_test.dart';

FindMyDevice device(Map<String, dynamic> values) => FindMyDevice.fromJson({
  'id': values['id'],
  'name': values['name'],
  'deviceModel': values['deviceModel'],
  'deviceClass': values['deviceClass'],
  'modelDisplayName': values['modelDisplayName'],
  'isAppleAudioAccessory': values['isAppleAudioAccessory'] ?? false,
  'isConsideredAccessory': values['isConsideredAccessory'] ?? false,
  'groupIdentifier': values['groupIdentifier'],
  'groupName': values['groupName'],
  'location': {'latitude': 32.0, 'longitude': -96.0},
});

void main() {
  test('AirPods components collapse into one product under Devices', () {
    final all = [
      device({'id': 'phone', 'name': 'Phone', 'deviceClass': 'iPhone'}),
      for (final role in ['left', 'right', 'Case'])
        device({
          'id': 'pods-$role',
          'name': role,
          'deviceModel': 'hawkeye',
          'deviceClass': 'hawkeye',
          'isAppleAudioAccessory': true,
          'isConsideredAccessory': true,
          'groupIdentifier': 'pods-group',
          'groupName': 'AirPods Pro',
        }),
      device({
        'id': 'wallet',
        'name': 'Wallet',
        'deviceModel': 'b389',
        'deviceClass': 'b389',
        'isConsideredAccessory': true,
      }),
    ];

    final devices = findMyDeviceProducts(all);
    final items = findMyItemProducts(all);

    expect(devices.map((e) => e.id), contains('phone'));
    expect(devices.where((e) => e.groupIdentifier == 'pods-group'), hasLength(1));
    expect(items.map((e) => e.id), ['wallet']);
  });

  test('a standalone AirPods parent belongs under Devices', () {
    final airPods = device({
      'id': 'airpods-max',
      'name': 'Headphones',
      'modelDisplayName': 'AirPods Max',
      'deviceClass': 'Accessory',
      'isConsideredAccessory': true,
    });

    expect(findMyDeviceProducts([airPods]), [airPods]);
    expect(findMyItemProducts([airPods]), isEmpty);
  });
}
