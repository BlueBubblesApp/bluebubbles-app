import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/handle_interface.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:dice_bear/dice_bear.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';
import 'package:bluebubbles/models/models.dart' show HandleLookupKey;

@Entity()
class Handle {
  int? id;
  int? originalROWID;
  @Unique()
  String uniqueAddressAndService;
  String address;
  String? formattedAddress;
  String service;
  String? country;
  String? defaultEmail;
  String? defaultPhone;

  String? color;

  // N:M Relationship to ContactV2 (new contact service)
  // This is a backlink - ContactV2 owns the relationship
  @Backlink('handles')
  final contactsV2 = ToMany<ContactV2>();

  @Transient()
  Widget? _fakeAvatar;

  @Transient()
  Widget get fakeAvatar {
    if (_fakeAvatar != null) return _fakeAvatar!;
    // Pick a random background color from the hex list: randomAvatarBackgroundColors
    final backgroundColor = randomAvatarBackgroundColors.randomChoice();

    Avatar _avatar = DiceBearBuilder(
      seed: address,
      sprite: DiceBearStyle.miniavs,
      // Random light color scheme with a custom background color to prevent white backgrounds on light mode
      backgroundColor: HexColor(backgroundColor),
    ).build();
    _fakeAvatar = _avatar.toImage();
    return _fakeAvatar!;
  }

  @Transient()
  String get displayName {
    if (address.startsWith("urn:biz")) return "Business";
    if (!kIsWeb && contactsV2.isNotEmpty) {
      // Prioritize native contacts, but fall back to any contact if no native ones exist (should be rare)
      final firstNativeContact = contactsV2.where((c) => c.isNative).firstOrNull;
      final nativeNickname = firstNativeContact?.nickname;
      if (!isNullOrEmpty(nativeNickname)) return nativeNickname!;

      final nativeDisplayName = firstNativeContact?.displayName;
      if (!isNullOrEmpty(nativeDisplayName)) return nativeDisplayName!;

      final computedDisplayName = contactsV2.first.computedDisplayName;
      if (!isNullOrEmpty(computedDisplayName)) return computedDisplayName;
    }

    // Formatted address should be filled out by sync. If it's missing,
    // format on demand so UI callers still get a readable phone number.
    return address.contains("@") ? address : (formattedAddress ?? formatPhoneNumber(address));
  }

  @Transient()
  String get reactionDisplayName {
    if (address.startsWith("urn:biz")) return "Business";
    if (!kIsWeb && contactsV2.isNotEmpty) {
      // Prioritize native contacts, but fall back to any contact if no native ones exist (should be rare)
      final firstNativeContact = contactsV2.where((c) => c.isNative).firstOrNull;
      final nativeNickname = firstNativeContact?.nickname;
      if (!isNullOrEmpty(nativeNickname)) return nativeNickname!;

      final nativeFirstName = firstNativeContact?.firstName;
      if (!isNullOrEmpty(nativeFirstName)) return nativeFirstName!;

      final nativeComputedDisplayName = firstNativeContact?.computedDisplayName;
      if (!isNullOrEmpty(nativeComputedDisplayName)) return nativeComputedDisplayName!;

      final computedDisplayName = contactsV2.first.computedDisplayName;
      if (!isNullOrEmpty(computedDisplayName)) return computedDisplayName;
    }

    // For reactions, we want to show the formatted address for phone numbers, but the regular address for emails
    return address.contains("@") ? address : (formattedAddress ?? address);
  }

  @Transient()
  String get shortName {
    return contactsV2.isNotEmpty ? reactionDisplayName.firstWord : reactionDisplayName;
  }

  @Transient()
  String? get initials {
    if (address.startsWith("urn:biz")) return null;

    // Check ContactV2 first for initials
    if (!kIsWeb && contactsV2.isNotEmpty) {
      final contactV2Initials = contactsV2.first.initials;
      if (contactV2Initials != null) return contactV2Initials;
    }

    // Split by space/dash/underscore and take first alpha of first + last word
    final parts = displayName.trim().split(RegExp(r'[ \-_]'));
    if (parts.length == 1) return parts[0].firstAlpha?.toUpperCase();

    final firstPart = (parts.first.firstAlpha ?? '').toUpperCase();
    final lastPart = (parts.last.firstAlpha ?? '').toUpperCase();

    return (firstPart + lastPart).isEmpty ? null : firstPart + lastPart;
  }

  Handle({
    this.id,
    this.originalROWID,
    this.address = "",
    this.formattedAddress,
    this.service = 'iMessage',
    this.uniqueAddressAndService = "",
    this.country,
    this.color,
    this.defaultEmail,
    this.defaultPhone,
  }) {
    if (service.isEmpty) {
      service = 'iMessage';
    }
    if (uniqueAddressAndService.isEmpty) {
      uniqueAddressAndService = "$address/$service";
    }
  }

  factory Handle.fromMap(Map<String, dynamic> json) => Handle(
        id: json["ROWID"] ?? json["id"],
        // Server participants payloads carry the sender ROWID under "ROWID" and
        // omit "originalROWID". Falling back preserves that ROWID as the
        // originalROWID so Message.handleId → Handle lookups succeed for
        // brand-new chats synced via bulkSyncChats.
        originalROWID: json["originalROWID"] ?? json["ROWID"],
        address: json["address"],
        formattedAddress: json["formattedAddress"],
        service: json["service"] ?? "iMessage",
        uniqueAddressAndService: json["uniqueAddrAndService"] ?? "${json["address"]}/${json["service"] ?? "iMessage"}",
        country: json["country"],
        color: json["color"],
        defaultPhone: json["defaultPhone"],
        defaultEmail: json["defaultEmail"],
      );

  /// Formats and sets the formattedAddress field if not already set.
  ///
  /// For emails and business chats (urn:biz), uses the address as-is.
  /// For phone numbers, formats them using the formatPhoneNumber helper.
  ///
  /// This should be called in isolate actions before saving handles to the database.
  Future<void> updateFormattedAddress() async {
    if (!isNullOrEmpty(formattedAddress)) return;

    if (address.contains('@') || address.startsWith('urn:biz')) {
      formattedAddress = address;
    } else {
      formattedAddress = formatPhoneNumber(address);
    }
  }

  /// Save a single handle - prefer [bulkSave] for multiple handles rather
  /// than iterating through them
  Handle save({bool updateColor = false, matchOnOriginalROWID = false}) {
    if (kIsWeb) return this;
    Database.runInTransaction(TxMode.write, () {
      Handle? existing;
      if (matchOnOriginalROWID) {
        existing = Handle.findOne(originalROWID: originalROWID);
      } else {
        existing = Handle.findOne(addressAndService: HandleLookupKey(address, service));
      }

      if (existing != null) {
        id = existing.id;
      }
      // Contact matching is now handled automatically by ContactServiceV2
      if (!updateColor) {
        color = existing?.color ?? color;
      }
      try {
        id = Database.handles.put(this);
      } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  /// Save a single handle asynchronously (non-blocking)
  Future<Handle> saveAsync({bool updateColor = false, matchOnOriginalROWID = false}) async {
    if (kIsWeb) return this;

    final savedHandle = await HandleInterface.saveHandleAsync(
      handleData: toMap(),
      updateColor: updateColor,
      matchOnOriginalROWID: matchOnOriginalROWID,
    );

    // Update this handle with the saved data
    id = savedHandle.id;
    color = savedHandle.color;

    return this;
  }

  /// Save a list of handles
  static List<Handle> bulkSave(List<Handle> handles, {matchOnOriginalROWID = false}) {
    Database.runInTransaction(TxMode.write, () {
      /// Match existing to the handles to save, where possible
      for (Handle h in handles) {
        Handle? existing;
        if (matchOnOriginalROWID) {
          existing = Handle.findOne(originalROWID: h.originalROWID);
        } else {
          existing = Handle.findOne(addressAndService: HandleLookupKey(h.address, h.service));
        }

        if (existing != null) {
          h.id = existing.id;
        }
        // Contact matching is now handled automatically by ContactServiceV2
      }

      List<int> insertedIds = Database.handles.putMany(handles);
      for (int i = 0; i < insertedIds.length; i++) {
        handles[i].id = insertedIds[i];
      }
    });

    return handles;
  }

  /// Save a list of handles asynchronously (non-blocking)
  static Future<List<Handle>> bulkSaveAsync(List<Handle> handles, {matchOnOriginalROWID = false}) async {
    if (kIsWeb) return handles;
    if (handles.isEmpty) return handles;

    final savedHandles = await HandleInterface.bulkSaveHandlesAsync(
      handlesData: handles.map((e) => e.toMap()).toList(),
      matchOnOriginalROWID: matchOnOriginalROWID,
    );

    // Update the handles with saved data
    for (int i = 0; i < handles.length; i++) {
      if (i < savedHandles.length) {
        handles[i].id = savedHandles[i].id;
        handles[i].color = savedHandles[i].color;
      }
    }

    return handles;
  }

  Handle updateColor(String? newColor) {
    color = newColor;
    save();
    return this;
  }

  Handle updateDefaultPhone(String newPhone) {
    defaultPhone = newPhone;
    save();
    return this;
  }

  Handle updateDefaultEmail(String newEmail) {
    defaultEmail = newEmail;
    save();
    return this;
  }

  static Handle? findOne({int? id, int? originalROWID, HandleLookupKey? addressAndService}) {
    if (kIsWeb || id == 0) return null;
    if (id != null) {
      final handle = Database.handles.get(id) ?? Handle.findOne(originalROWID: id);
      return handle;
    } else if (originalROWID != null) {
      final query = Database.handles.query(Handle_.originalROWID.equals(originalROWID)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    } else if (addressAndService != null) {
      final query = Database.handles
          .query(Handle_.address.equals(addressAndService.address) & Handle_.service.equals(addressAndService.service))
          .build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    }
    return null;
  }

  static Future<Handle?> findOneAsync({int? id, int? originalROWID, HandleLookupKey? addressAndService}) async {
    if (kIsWeb || id == 0) return null;

    return await HandleInterface.findOneHandleAsync(
      id: id,
      originalROWID: originalROWID,
      address: addressAndService?.address,
      service: addressAndService?.service,
    );
  }

  static Handle merge(Handle handle1, Handle handle2) {
    handle1.id ??= handle2.id;
    handle1.originalROWID ??= handle2.originalROWID;
    handle1.color ??= handle2.color;
    handle1.country ??= handle2.country;
    handle1.formattedAddress ??= handle2.formattedAddress;
    if (isNullOrEmpty(handle1.defaultPhone)) {
      handle1.defaultPhone = handle2.defaultPhone;
    }
    if (isNullOrEmpty(handle1.defaultEmail)) {
      handle1.defaultEmail = handle2.defaultEmail;
    }

    return handle1;
  }

  /// Find a list of handles by the specified condition, or return all handles
  /// when no condition is specified
  static List<Handle> find({Condition<Handle>? cond}) {
    final query = Database.handles.query(cond).build();
    return query.find();
  }

  static Future<List<Handle>> findAsync({Condition<Handle>? cond}) async {
    if (kIsWeb) return [];

    // Note: For now, we don't serialize conditions for cross-isolate communication
    // This will return all handles. Future enhancement can add condition serialization.
    return await HandleInterface.findHandlesAsync();
  }

  Map<String, dynamic> toMap() {
    return {
      "ROWID": id,
      "originalROWID": originalROWID,
      "address": address,
      "formattedAddress": formattedAddress,
      "service": service,
      "uniqueAddrAndService": uniqueAddressAndService,
      "country": country,
      "color": color,
      "defaultPhone": defaultPhone,
      "defaultEmail": defaultEmail,
    };
  }
}
