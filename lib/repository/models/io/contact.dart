import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/repository/models/models.dart';
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

@Entity()
class Contact {
  Contact({
    this.dbId,
    required this.id,
    required this.displayName,
    this.phones = const [],
    this.formattedPhones = const [],
    this.emails = const [],
    this.structuredName,
    required this.fakeName,
    this.avatar,
    this.avatarHiRes,
  }) {
    if (formattedPhones.isEmpty) {
      formattedPhones = List<String>.from(phones);
    }
  }

  @Id()
  int? dbId;
  @Index()
  String id;
  String displayName;
  List<String> phones;
  List<String> formattedPhones;
  List<String> emails;
  StructuredName? structuredName;
  String fakeName;
  Uint8List? avatar;
  Uint8List? avatarHiRes;
  
  Map<String, String>? get dbStructuredName => structuredName?.toMap();
  set dbStructuredName(Map<String, String>? map) => StructuredName.fromMap(map);

  Uint8List? getAvatar({prioritizeHiRes = false}) {
    if (prioritizeHiRes) {
      return avatarHiRes ?? avatar;
    } else {
      return avatar ?? avatarHiRes;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'phoneNumbers': getUniqueNumbers(phones),
      'emails': getUniqueEmails(emails),
      'fakeName': fakeName,
      'avatar': avatarHiRes != null || avatar != null ? base64Encode(avatarHiRes ?? avatar!) : null,
    };
  }
}