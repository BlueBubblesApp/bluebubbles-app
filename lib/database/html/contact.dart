import 'dart:convert';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class Contact {
  Contact({
    this.dbId,
    required this.id,
    required this.displayName,
    this.phones = const [],
    this.emails = const [],
    this.structuredName,
    this.avatar,
  });

  int? dbId;
  String id;
  String displayName;
  List<String> phones;
  List<String> emails;
  StructuredName? structuredName;
  Uint8List? avatar;

  Map<String, String>? get dbStructuredName => structuredName?.toMap();
  set dbStructuredName(Map<String, String>? map) => StructuredName.fromMap(map);

  String? get initials {
    String initials = (structuredName?.givenName.characters.firstOrNull ?? "") + (structuredName?.familyName.characters.firstOrNull ?? "");
    // If the initials are empty, get them from the display name
    if (initials.trim().isEmpty) {
      initials = displayName.characters.firstOrNull ?? "";
    }

    return initials.isEmpty ? null : initials.toUpperCase();
  }

  static List<Contact> getContacts() {
    return [];
  }

  Contact save() {
    return this;
  }

  static Contact? findOne({String? id, String? address}) {
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'dbId': dbId,
      'id': id,
      'displayName': displayName,
      'phoneNumbers': getUniqueNumbers(phones),
      'emails': getUniqueEmails(emails),
      'structuredName': structuredName?.toMap(),
      'avatar': avatar == null ? null : base64Encode(avatar!),
    };
  }

  static Contact fromMap(Map<String, dynamic> m) {
    return Contact(
      dbId: m['dbId'],
      id: m['id'],
      displayName: m['displayName'],
      phones: m['phoneNumbers'],
      emails: m['emails'],
      structuredName: StructuredName.fromMap(m['structuredName']),
      avatar: m['avatar'] == null ? null : base64Decode(m['avatar']!),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Contact &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              displayName == other.displayName &&
              phones == other.phones &&
              emails == other.emails &&
              avatar?.length == other.avatar?.length;

  @override
  int get hashCode => id.hashCode;
}