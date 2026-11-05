import 'dart:typed_data';

import 'package:bluebubbles/database/html/handle.dart';
import 'package:flutter/material.dart';

/// Web stub for ContactV2 - minimal implementation for web compatibility
class ContactV2 {
  ContactV2({
    this.id = 0,
    required this.displayName,
    required this.nativeContactId,
    this.avatarPath,
    this.addresses = const [],
  });

  int id;
  String displayName;
  String nativeContactId;
  String? avatarPath;
  List<String> addresses;

  String get computedDisplayName => displayName;

  // Stub properties for web
  Widget? _fakeAvatar;
  Widget get fakeAvatar => _fakeAvatar ?? Container();

  String? get initials {
    final parts = displayName.trim().split(' ');
    if (parts.isEmpty || displayName.isEmpty) return null;

    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : null;
    }

    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';

    return (first + last).isEmpty ? null : (first + last).toUpperCase();
  }

  Future<Uint8List?> loadAvatar() async => null;

  static String normalizePhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  static String normalizeEmail(String email) {
    return email.toLowerCase().trim();
  }

  List<Handle> get handles => const [];

  bool hasMatchingAddress(String address) {
    final normalized = address.contains('@') ? normalizeEmail(address) : normalizePhoneNumber(address);

    return addresses.any((contactAddress) {
      final contactNormalized =
          contactAddress.contains('@') ? normalizeEmail(contactAddress) : normalizePhoneNumber(contactAddress);
      return contactNormalized == normalized;
    });
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'nativeContactId': nativeContactId,
      'avatarPath': avatarPath,
      'addresses': addresses,
    };
  }

  static ContactV2 fromMap(Map<String, dynamic> map) {
    return ContactV2(
      id: map['id'] ?? 0,
      displayName: map['displayName'] ?? '',
      nativeContactId: map['nativeContactId'] ?? '',
      avatarPath: map['avatarPath'],
      addresses: List<String>.from(map['addresses'] ?? []),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactV2 &&
          runtimeType == other.runtimeType &&
          nativeContactId == other.nativeContactId &&
          displayName == other.displayName);

  @override
  int get hashCode => Object.hash(nativeContactId, displayName);
}
