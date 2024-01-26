import 'dart:convert';

import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/global/contact_address.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    this.emails = const [],
    this.phoneNumbers = const [],
    this.emailAddresses = const [],
    this.structuredName,
    this.avatar,
  });

  @Id()
  int? dbId;
  @Index()
  String id;
  String displayName;
  StructuredName? structuredName;
  Uint8List? avatar;

  String? get dbStructuredName => structuredName == null
      ? null : jsonEncode(structuredName!.toMap());
  set dbStructuredName(String? json) => structuredName = json == null
      ? null : StructuredName.fromMap(jsonDecode(json));

  @Deprecated('Use phoneNumbers instead')
  List<String> phones;
  @Deprecated('Use emailAddresses instead')
  List<String> emails;

  List<ContactAddress> phoneNumbers;
  List<ContactAddress> emailAddresses;

  String? get dbPhones => jsonEncode(phoneNumbers.map((e) => e.toMap()).toList());
  set dbPhones(String? json) => (json == null) ? [] : (jsonDecode(json) as List<dynamic>).map((e) => ContactAddress.fromMap(e)).toList();

  String? get dbEmails => jsonEncode(emailAddresses.map((e) => e.toMap()).toList());
  set dbEmails(String? json) => (json == null) ? [] : (jsonDecode(json) as List<dynamic>).map((e) => ContactAddress.fromMap(e)).toList();

  String? get initials {
    String initials = (structuredName?.givenName.characters.firstOrNull ?? "") + (structuredName?.familyName.characters.firstOrNull ?? "");
    // If the initials are empty, get them from the display name
    if (initials.trim().isEmpty) {
      initials = displayName.characters.firstOrNull ?? "";
    }

    return initials.isEmpty ? null : initials.toUpperCase();
  }

  static List<Contact> getContacts() {
    return contactBox.getAll();
  }

  Contact save() {
    if (kIsWeb) return this;
    store.runInTransaction(TxMode.write, () {
      Contact? existing = Contact.findOne(id: id);
      if (existing != null) {
        dbId = existing.dbId;
      }
      try {
        dbId = contactBox.put(this);
      } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  static Contact? findOne({String? id, String? address}) {
    if (kIsWeb) return null;
    if (id != null) {
      final query = contactBox.query(Contact_.id.equals(id)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    } else if (address != null) {
      final query = contactBox.query(Contact_.phones.containsElement(address) | Contact_.emails.containsElement(address)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'dbId': dbId,
      'id': id,
      'displayName': displayName,
      'phoneNumbers': getUniqueNumbers(phoneNumbers),
      'emails': getUniqueEmails(emailAddresses),
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
      (other is Contact &&
          runtimeType == other.runtimeType &&
          displayName == other.displayName &&
          listEquals(getUniqueNumbers(phoneNumbers), getUniqueNumbers(other.phoneNumbers)) &&
          listEquals(getUniqueEmails(emailAddresses), getUniqueEmails(other.emailAddresses)) &&
          avatar?.length == other.avatar?.length);

  @override
  int get hashCode => Object.hashAllUnordered([displayName, avatar?.length, ...getUniqueNumbers(phoneNumbers), ...getUniqueEmails(emailAddresses)]);
}