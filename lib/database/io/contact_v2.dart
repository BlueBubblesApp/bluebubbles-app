import 'dart:convert';

import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:dice_bear/dice_bear.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Necessary for ObjectBox annotations
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

/// A phone number with an associated label (e.g., "mobile", "work", "home").
class ContactPhone {
  final String number;
  final String label;

  const ContactPhone({required this.number, required this.label});

  Map<String, dynamic> toMap() => {'number': number, 'label': label};

  static ContactPhone fromMap(Map<String, dynamic> m) =>
      ContactPhone(number: m['number'] ?? '', label: m['label'] ?? '');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ContactPhone && number == other.number && label == other.label);

  @override
  int get hashCode => Object.hash(number, label);
}

/// An email address with an associated label (e.g., "work", "home").
class ContactEmail {
  final String address;
  final String label;

  const ContactEmail({required this.address, required this.label});

  Map<String, dynamic> toMap() => {'address': address, 'label': label};

  static ContactEmail fromMap(Map<String, dynamic> m) =>
      ContactEmail(address: m['address'] ?? '', label: m['label'] ?? '');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ContactEmail && address == other.address && label == other.label);

  @override
  int get hashCode => Object.hash(address, label);
}

/// ContactV2 - New contact entity designed for N:M relationship with Handles
/// This entity follows the architecture outlined in FR-1.md
@Entity()
class ContactV2 {
  ContactV2({
    this.id = 0,
    required this.displayName,
    required this.nativeContactId,
    this.isNative = false,
    this.avatarPath,
    this.addresses = const [],
    this.nickname,
    this.firstName,
    this.lastName,
    this.middleName,
    this.namePrefix,
    this.nameSuffix,
    this.company,
  });

  @Id()
  int id;

  /// Display name of the contact
  String displayName;

  /// Contact ID. May be "native", or not, depending on if it
  /// originated from the device's native contact store or was created on the server.
  /// The name is a bit misleading, but I don't want to rename it at this point.
  @Index()
  @Unique()
  String nativeContactId;

  /// Local file path to the avatar image (if any)
  String? avatarPath;

  /// Normalized list of phone numbers and emails
  /// Phone numbers should be stripped of non-digits
  /// Emails should be lowercased
  List<String> addresses;

  // --- Structured name fields ---
  String? nickname;
  String? firstName;
  String? lastName;
  String? middleName;
  String? namePrefix;
  String? nameSuffix;

  /// Company / organization name
  String? company;

  /// Whether this contact originated from the device's native contact store
  /// (flutter_contacts). False for contacts synced from the BlueBubbles server.
  bool isNative = false;

  // --- Labeled phones (JSON-backed) ---
  /// In-memory list of phones with labels. ObjectBox stores [dbPhoneNumbers].
  @Transient()
  List<ContactPhone> phoneNumbers = [];

  String? get dbPhoneNumbers => phoneNumbers.isEmpty ? null : jsonEncode(phoneNumbers.map((e) => e.toMap()).toList());

  set dbPhoneNumbers(String? json) {
    phoneNumbers = json == null
        ? []
        : (jsonDecode(json) as List).map((e) => ContactPhone.fromMap(e as Map<String, dynamic>)).toList();
  }

  // --- Labeled emails (JSON-backed) ---
  /// In-memory list of emails with labels. ObjectBox stores [dbEmailAddresses].
  @Transient()
  List<ContactEmail> emailAddresses = [];

  String? get dbEmailAddresses =>
      emailAddresses.isEmpty ? null : jsonEncode(emailAddresses.map((e) => e.toMap()).toList());

  set dbEmailAddresses(String? json) {
    emailAddresses = json == null
        ? []
        : (jsonDecode(json) as List).map((e) => ContactEmail.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// N:M Relationship to Handles
  /// This establishes the many-to-many relationship between contacts and handles
  final handles = ToMany<Handle>();

  @Transient()
  Widget? _fakeAvatar;

  @Transient()
  Widget get fakeAvatar {
    if (_fakeAvatar != null) return _fakeAvatar!;
    Avatar _avatar = DiceBearBuilder(seed: displayName).build();
    _fakeAvatar = _avatar.toImage();
    return _fakeAvatar!;
  }

  /// Returns the best display name: prefers nickname, then first+last, then raw displayName.
  String get computedDisplayName {
    if (nickname != null && nickname!.isNotEmpty) return nickname!;
    final first = firstName ?? '';
    final last = lastName ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    return displayName;
  }

  /// Get the initials from the structured name, falling back to display name.
  /// Only alphabetical characters are considered; returns null if none are found.
  String? get initials {
    // Prefer structured first/last name when available
    final first = firstName.firstAlpha;
    final last = lastName.firstAlpha;

    if (first != null || last != null) {
      return ((first ?? '') + (last ?? '')).toUpperCase();
    }

    // Fall back to display name
    final parts = displayName.trim().split(' ');
    if (parts.isEmpty || displayName.isEmpty) return null;

    if (parts.length == 1) {
      return parts[0].firstAlpha?.toUpperCase();
    }

    final firstPart = parts.first.firstAlpha ?? '';
    final lastPart = parts.last.firstAlpha ?? '';

    return (firstPart + lastPart).isEmpty ? null : (firstPart + lastPart).toUpperCase();
  }

  /// Normalize a phone number by removing all non-digit characters
  static String normalizePhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Normalize an email by converting to lowercase and trimming
  static String normalizeEmail(String email) {
    return email.toLowerCase().trim();
  }

  /// Check if an address matches any of this contact's addresses
  bool hasMatchingAddress(String address) {
    final normalized = address.contains('@') ? normalizeEmail(address) : normalizePhoneNumber(address);

    return addresses.any((contactAddress) {
      final contactNormalized =
          contactAddress.contains('@') ? normalizeEmail(contactAddress) : normalizePhoneNumber(contactAddress);
      return contactNormalized == normalized;
    });
  }

  /// Formats this contact for the server upload API.
  /// Field names match what the server expects (and sends back on fetch).
  Map<String, dynamic> toServerMap() {
    return {
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumbers': phoneNumbers.map((e) => e.number).toList(),
      'emails': emailAddresses.map((e) => e.address).toList(),
      // Server supports avatars, but all we have right now is a path to it.
      // Fetching it and converting to base64 is a bit too much for now, so we'll skip it.
      // 'avatar': avatarPath != null ? base64Encode(File(avatarPath!).readAsBytesSync()) : null,
      // Not supported on server yet
      // 'middleName': middleName,
      // 'nickname': nickname,
    };
  }

  /// Convert to map for cross-isolate serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'nativeContactId': nativeContactId,
      'avatarPath': avatarPath,
      'addresses': addresses,
      'nickname': nickname,
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'namePrefix': namePrefix,
      'nameSuffix': nameSuffix,
      'company': company,
      'isNative': isNative,
      'phoneNumbers': phoneNumbers.map((e) => e.toMap()).toList(),
      'emailAddresses': emailAddresses.map((e) => e.toMap()).toList(),
    };
  }

  /// Create from map (cross-isolate deserialization)
  static ContactV2 fromMap(Map<String, dynamic> map) {
    final c = ContactV2(
      id: map['id'] ?? 0,
      displayName: map['displayName'] ?? '',
      nativeContactId: map['nativeContactId'] ?? '',
      isNative: map['isNative'] ?? false,
      avatarPath: map['avatarPath'],
      addresses: List<String>.from(map['addresses'] ?? []),
      nickname: map['nickname'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      middleName: map['middleName'],
      namePrefix: map['namePrefix'],
      nameSuffix: map['nameSuffix'],
      company: map['company'],
    );
    if (map['phoneNumbers'] != null) {
      c.phoneNumbers =
          (map['phoneNumbers'] as List).map((e) => ContactPhone.fromMap(e as Map<String, dynamic>)).toList();
    }
    if (map['emailAddresses'] != null) {
      c.emailAddresses =
          (map['emailAddresses'] as List).map((e) => ContactEmail.fromMap(e as Map<String, dynamic>)).toList();
    }
    return c;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactV2 &&
          runtimeType == other.runtimeType &&
          nativeContactId == other.nativeContactId &&
          displayName == other.displayName &&
          listEquals(addresses, other.addresses) &&
          avatarPath == other.avatarPath);

  @override
  int get hashCode => Object.hash(
        nativeContactId,
        displayName,
        Object.hashAll(addresses),
        avatarPath,
      );
}
