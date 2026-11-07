import 'dart:typed_data';

import 'package:bluebubbles/database/models.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

/// The name and photo one participant shared through Messages' name and photo sharing. A shared name is only a
/// suggestion for a contact, never a display name.
class SharedNameAndPhoto {
  SharedNameAndPhoto(this.handle, this.name, this.avatar)
      : contact = handle.contactsV2.firstWhereOrNull((c) => c.isNative),
        photoHash = avatar == null ? null : md5.convert(avatar).toString();

  final Handle handle;
  final String? name;
  final Uint8List? avatar;

  /// The device contact this participant is saved as, which a shared photo can update
  final ContactV2? contact;

  /// Identifies the shared photo, so one the user dismissed isn't offered again until it changes
  final String? photoHash;

  /// No contact yet: offered as one to add rather than a photo to update
  bool get isNewContact => contact == null;

  String get label => contact?.displayName ?? name ?? handle.displayName;
}
