export 'package:bluebubbles/repository/models/unsupported/attachment.dart'
if (dart.library.html) 'package:bluebubbles/repository/models/html/attachment.dart'
if (dart.library.io) 'package:bluebubbles/repository/models/io/attachment.dart';

export 'package:bluebubbles/repository/models/unsupported/chat.dart'
if (dart.library.html) 'package:bluebubbles/repository/models/html/chat.dart'
if (dart.library.io) 'package:bluebubbles/repository/models/io/chat.dart';

export 'package:bluebubbles/repository/models/unsupported/fcm_data.dart'
if (dart.library.html) 'package:bluebubbles/repository/models/html/fcm_data.dart'
if (dart.library.io) 'package:bluebubbles/repository/models/io/fcm_data.dart';

export 'package:bluebubbles/repository/models/unsupported/handle.dart'
if (dart.library.html) 'package:bluebubbles/repository/models/html/handle.dart'
if (dart.library.io) 'package:bluebubbles/repository/models/io/handle.dart';

export 'package:bluebubbles/repository/models/unsupported/join_tables.dart'
if (dart.library.html) 'package:bluebubbles/repository/models/html/join_tables.dart'
if (dart.library.io) 'package:bluebubbles/repository/models/io/join_tables.dart';

export 'package:bluebubbles/repository/models/unsupported/message.dart'
if (dart.library.html) 'package:bluebubbles/repository/models/html/message.dart'
if (dart.library.io) 'package:bluebubbles/repository/models/io/message.dart';

export 'package:bluebubbles/repository/models/unsupported/scheduled.dart'
if (dart.library.html) 'package:bluebubbles/repository/models/html/scheduled.dart'
if (dart.library.io) 'package:bluebubbles/repository/models/io/scheduled.dart';

export 'package:bluebubbles/repository/models/unsupported/theme_entry.dart'
if (dart.library.html) 'package:bluebubbles/repository/models/html/theme_entry.dart'
if (dart.library.io) 'package:bluebubbles/repository/models/io/theme_entry.dart';

export 'package:bluebubbles/repository/models/unsupported/theme_object.dart'
if (dart.library.html) 'package:bluebubbles/repository/models/html/theme_object.dart'
if (dart.library.io) 'package:bluebubbles/repository/models/io/theme_object.dart';

import 'dart:typed_data';

import 'package:fast_contacts/fast_contacts.dart';

class Contact {
  Contact({
    required this.id,
    required this.displayName,
    this.phones = const [],
    this.emails = const [],
    this.structuredName,
    this.avatar,
  });

  String id;
  String displayName;
  List<String> phones;
  List<String> emails;
  StructuredName? structuredName;
  Uint8List? avatar;

  Map<String, dynamic> toMap() {
    return {
      'id': this.id,
      'displayName': this.displayName,
      'phones': this.phones,
      'emails': this.emails,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      phones: map['phones'] as List<String>,
      emails: map['emails'] as List<String>,
    );
  }
}