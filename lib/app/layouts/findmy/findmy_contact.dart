import 'package:bluebubbles/database/models.dart';

/// Returns the real phone/email address Find My supplied for contact matching.
/// A display title is never an address.
String? findMyContactLookupAddress(FindMyFriend friend) {
  final address = (friend.handle?.address ?? friend.handleAddress)?.trim();
  if (address == null || address.isEmpty) return null;
  if (address.contains('@')) return address;
  final digits = address.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 5 ? address : null;
}
