import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:get/get.dart';
import 'package:image_size_getter/image_size_getter.dart';

export 'package:bluebubbles/repository/models/io/attachment.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/attachment.dart';
export 'package:bluebubbles/repository/models/io/chat.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/chat.dart';
export 'package:bluebubbles/repository/models/io/fcm_data.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/fcm_data.dart';
export 'package:bluebubbles/repository/models/io/handle.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/handle.dart';
export 'package:bluebubbles/repository/models/io/join_tables.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/join_tables.dart';
export 'package:bluebubbles/repository/models/io/js.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/js.dart';
export 'package:bluebubbles/repository/models/io/launch_at_startup.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/launch_at_startup.dart';
export 'package:bluebubbles/repository/models/io/message.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/message.dart';
export 'package:bluebubbles/repository/models/io/scheduled.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/scheduled.dart';
export 'package:bluebubbles/repository/models/io/theme.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/theme.dart';
export 'package:bluebubbles/repository/models/io/theme_entry.dart'
  if (dart.library.html) 'package:bluebubbles/repository/models/html/theme_entry.dart';
export 'package:bluebubbles/repository/models/io/theme_object.dart'
  if (dart.library.html) 'package:bluebubbles/repository/models/html/theme_object.dart';
export 'package:bluebubbles/repository/models/io/giphy.dart'
    if (dart.library.html) 'package:bluebubbles/repository/models/html/giphy.dart';
export 'package:bluebubbles/repository/models/platform_file.dart';
export 'package:bluebubbles/repository/models/attributed_body.dart';

class Contact {
  Contact({
    required this.id,
    required this.displayName,
    this.phones = const [],
    this.emails = const [],
    this.structuredName,
    this.fakeName,
    this.fakeAddress,
    Uint8List? avatarBytes,
    Uint8List? avatarHiResBytes,
  }) {
    avatar.value = avatarBytes;
    avatarHiRes.value = avatarHiResBytes;
  }

  String id;
  String displayName;
  List<String> phones;
  List<String> emails;
  StructuredName? structuredName;
  String? fakeName;
  String? fakeAddress;
  final Rxn<Uint8List> avatar = Rxn<Uint8List>();
  final Rxn<Uint8List> avatarHiRes = Rxn<Uint8List>();

  bool get hasAvatar {
    bool hasNormal = avatar.value != null && avatar.value!.isNotEmpty;
    bool hasHiRes = avatarHiRes.value != null && avatarHiRes.value!.isNotEmpty;
    return hasNormal || hasHiRes;
  }

  Uint8List? getAvatar({prioritizeHiRes = false}) {
    if (!hasAvatar) return null;

    if (prioritizeHiRes) {
      return avatarHiRes.value ?? avatar.value;
    } else {
      return avatar.value ?? avatarHiRes.value;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'phoneNumbers': getUniqueNumbers(phones),
      'emails': getUniqueEmails(emails),
      'fakeName': fakeName,
      'fakeAddress': fakeAddress,
      'avatar': avatarHiRes.value != null || avatar.value != null ? base64Encode(avatarHiRes.value ?? avatar.value!) : null,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    // backwards compatibility with old contacts plugin
    if (map['phones'].isNotEmpty && map['phones'][0] is Map<String, dynamic>) {
      map['phones'] = map['phones'].map((e) => e['value'] ?? "").toList();
    }
    if (map['emails'].isNotEmpty && map['emails'][0] is Map<String, dynamic>) {
      map['emails'] = map['emails'].map((e) => e['value'] ?? "").toList();
    }
    return Contact(
        id: (map['id'] ?? map['identifier']) as String,
        displayName: map['displayName'] as String,
        phones: map['phones'].cast<String>(),
        emails: map['emails'].cast<String>(),
        fakeName: map['fakeName'],
        fakeAddress: map['fakeAddress']);
  }
}

class AsyncInput extends AsyncImageInput {
  AsyncInput(this._input);

  /// The input data of [ImageInput].
  final ImageInput _input;

  @override
  Future<bool> supportRangeLoad() async {
    return true;
  }

  @override
  Future<bool> exists() async {
    return _input.exists();
  }

  @override
  Future<List<int>> getRange(int start, int end) async {
    return _input.getRange(start, end);
  }

  @override
  Future<int> get length async => _input.length;

  @override
  Future<HaveResourceImageInput> delegateInput() async {
    return HaveResourceImageInput(innerInput: _input);
  }
}
