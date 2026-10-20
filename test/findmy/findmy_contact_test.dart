import 'package:bluebubbles/app/layouts/findmy/findmy_contact.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter_test/flutter_test.dart';

FindMyFriend friend({String? handle, String? title}) => FindMyFriend(
  latitude: null,
  longitude: null,
  longAddress: null,
  shortAddress: null,
  title: title,
  subtitle: null,
  handle: null,
  handleAddress: handle,
  lastUpdated: null,
  status: null,
  locatingInProgress: false,
  favoriteOrder: null,
);

void main() {
  test('uses a raw phone address when no exact iMessage handle exists', () {
    expect(findMyContactLookupAddress(friend(handle: '+12145550123', title: 'Saved person')), '+12145550123');
  });

  test('uses a raw email address when no exact iMessage handle exists', () {
    expect(findMyContactLookupAddress(friend(handle: 'person@example.com', title: 'Saved person')), 'person@example.com');
  });

  test('does not use a display title as a contact address', () {
    expect(findMyContactLookupAddress(friend(title: 'Saved Person')), isNull);
  });
}
