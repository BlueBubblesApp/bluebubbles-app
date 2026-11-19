import 'package:bluebubbles/services/backend/actions/contact_v2_actions.dart';
import 'package:flutter_test/flutter_test.dart';

const _device = 'phone-a';

/// A contact as [ContactV2.toServerMap] builds it for upload.
Map<String, dynamic> _local(
  String nativeId, {
  String? firstName = 'Alex',
  String? lastName = 'Doe',
  String displayName = 'Alex Doe',
  List<String> phones = const ['+15550001111'],
  List<String> emails = const [],
  String device = _device,
}) =>
    {
      'externalId': '$device:$nativeId',
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumbers': phones,
      'emails': emails,
    };

/// A contact as the server returns it: addresses as `{address}` objects.
Map<String, dynamic> _server(
  int id, {
  String? externalId,
  String sourceType = 'db',
  String? firstName = 'Alex',
  String? lastName = 'Doe',
  String displayName = 'Alex Doe',
  List<String> phones = const ['+15550001111'],
  List<String> emails = const [],
}) =>
    {
      'id': id,
      'externalId': externalId,
      'sourceType': sourceType,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumbers': [for (final p in phones) {'address': p}],
      'emails': [for (final e in emails) {'address': e}],
    };

void main() {
  group('planContactUpload', () {
    test('an unchanged contact needs no request', () {
      final plan = ContactV2Actions.planContactUpload(
        [_server(1, externalId: '$_device:10')],
        [_local('10')],
        deviceId: _device,
      );
      expect(plan.updates, isEmpty);
      expect(plan.creates, isEmpty);
      expect(plan.deletes, isEmpty);
    });

    test('addresses compare as sets, whatever order the server returns them in', () {
      final plan = ContactV2Actions.planContactUpload(
        [_server(1, externalId: '$_device:10', phones: ['+2', '+1'])],
        [_local('10', phones: ['+1', '+2'])],
        deviceId: _device,
      );
      expect(plan.updates, isEmpty);
    });

    test('a renamed contact is updated in place, not created again', () {
      final plan = ContactV2Actions.planContactUpload(
        [_server(1, externalId: '$_device:10')],
        [_local('10', firstName: 'Sam', displayName: 'Sam Doe')],
        deviceId: _device,
      );
      expect(plan.creates, isEmpty);
      expect(plan.updates, hasLength(1));
      expect(plan.updates.single['id'], 1);
      expect(plan.updates.single['firstName'], 'Sam');
    });

    test('a removed number is sent as an update', () {
      final plan = ContactV2Actions.planContactUpload(
        [_server(1, externalId: '$_device:10', phones: ['+1', '+2'])],
        [_local('10', phones: ['+1'])],
        deviceId: _device,
      );
      expect(plan.updates.single['phoneNumbers'], ['+1']);
    });

    test('a contact the server lacks is created', () {
      final plan = ContactV2Actions.planContactUpload([], [_local('10')], deviceId: _device);
      expect(plan.creates.single['externalId'], '$_device:10');
    });

    test('only this phone\'s contacts that it no longer has are deleted', () {
      final plan = ContactV2Actions.planContactUpload(
        [
          _server(1, externalId: '$_device:10'),
          _server(2, externalId: '$_device:11'),
          _server(3, externalId: 'phone-b:11'),
        ],
        [_local('10')],
        deviceId: _device,
      );
      expect(plan.deletes, [2]);
    });

    test('an empty local list deletes nothing', () {
      final plan = ContactV2Actions.planContactUpload(
        [_server(1, externalId: '$_device:10')],
        [],
        deviceId: _device,
      );
      expect(plan.deletes, isEmpty);
    });

    test('a contact uploaded before externalId is claimed by name and given one', () {
      final plan = ContactV2Actions.planContactUpload([_server(1)], [_local('10')], deviceId: _device);
      expect(plan.creates, isEmpty);
      expect(plan.updates.single['id'], 1);
      expect(plan.updates.single['externalId'], '$_device:10');
    });

    test('each legacy entry is claimed by one local contact only', () {
      final plan = ContactV2Actions.planContactUpload([_server(1)], [_local('10'), _local('11')], deviceId: _device);
      expect(plan.updates.single['id'], 1);
      expect(plan.creates.single['externalId'], '$_device:11');
    });

    test('the Mac\'s own contacts are never matched or deleted', () {
      final plan = ContactV2Actions.planContactUpload(
        [_server(1, sourceType: 'api'), _server(2, sourceType: 'api', externalId: '$_device:99')],
        [_local('10')],
        deviceId: _device,
      );
      expect(plan.updates, isEmpty);
      expect(plan.creates, hasLength(1));
      expect(plan.deletes, isEmpty);
    });
  });
}
