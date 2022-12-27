import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:collection/collection.dart';
import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Condition;
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

@Entity()
class Handle {
  int? id;
  int? originalROWID;
  @Unique()
  String address;
  String? formattedAddress;
  String? country;
  String? defaultEmail;
  String? defaultPhone;
  @Transient()
  final String fakeName = faker.person.name();

  final RxnString _color = RxnString();
  String? get color => _color.value;
  set color(String? val) => _color.value = val;

  final contactRelation = ToOne<Contact>();
  @Transient()
  Contact? webContact;

  Contact? get contact => kIsWeb ? webContact : contactRelation.target;
  String get displayName {
    if (ss.settings.redactedMode.value) {
      if (ss.settings.generateFakeContactNames.value) {
        return fakeName;
      } else if (ss.settings.hideContactInfo.value) {
        return "";
      }
    }
    if (address.startsWith("urn:biz")) return "Business";
    if (contact != null) return contact!.displayName;
    return address.contains("@") ? address : (formattedAddress ?? address);
  }
  String? get initials {
    // Remove any numbers, certain symbols, and non-alphabet characters
    if (address.startsWith("urn:biz")) return null;
    String importantChars = displayName.toUpperCase().replaceAll(RegExp(r'[^a-zA-Z _-]'), "").trim();
    if (importantChars.isEmpty) return null;

    // Split by a space or special character delimiter, take each of the items and
    // reduce it to just the capitalized first letter. Then join the array by an empty char
    String reduced = importantChars
        .split(RegExp(r' |-|_'))
        .take(2)
        .map((e) => e.isEmpty ? '' : e[0].toUpperCase())
        .join('');
    return reduced.isEmpty ? null : reduced;
  }

  Handle({
    this.id,
    this.originalROWID,
    this.address = "",
    this.formattedAddress,
    this.country,
    String? handleColor,
    this.defaultEmail,
    this.defaultPhone,
  }) {
    color = handleColor;
  }

  factory Handle.fromMap(Map<String, dynamic> json) => Handle(
    id: json["ROWID"] ?? json["id"],
    originalROWID: json["originalROWID"],
    address: json["address"],
    formattedAddress: json["formattedAddress"],
    country: json["country"],
    handleColor: json["color"],
    defaultPhone: json['defaultPhone'],
  );

  /// Save a single handle - prefer [bulkSave] for multiple handles rather
  /// than iterating through them
  Handle save({bool updateColor = false}) {
    if (kIsWeb) return this;
    store.runInTransaction(TxMode.write, () {
      Handle? existing = Handle.findOne(address: address);
      if (existing != null) {
        id = existing.id;
        contactRelation.target = existing.contactRelation.target;
      } else if (existing == null && contactRelation.target == null) {
        contactRelation.target = cs.matchHandleToContact(this);
      }
      if (!updateColor) {
        color = existing?.color ?? color;
      }
      try {
        id = handleBox.put(this);
      } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  /// Save a list of handles
  static List<Handle> bulkSave(List<Handle> handles) {
    store.runInTransaction(TxMode.write, () {
      /// Find a list of existing handles
      List<Handle> existingHandles = Handle.find(cond: Handle_.address.oneOf(handles.map((e) => e.address).toList()));

      /// Match existing to the handles to save, where possible
      for (Handle h in handles) {
        final existing = existingHandles.firstWhereOrNull((e) => e.address == h.address);
        if (existing != null) {
          h.id = existing.id;
        }
      }
      try {
        /// Save the handles and update their IDs
        final ids = handleBox.putMany(handles);
        for (int i = 0; i < handles.length; i++) {
          handles[i].id = ids[i];
        }
      } on UniqueViolationException catch (_) {}
    });
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

  static Handle? findOne({int? id, int? originalROWID, String? address}) {
    if (kIsWeb || id == 0) return null;
    if (id != null) {
      final handle = handleBox.get(id) ?? Handle.findOne(originalROWID: id);
      return handle;
    } else if (originalROWID != null) {
      final query = handleBox.query(Handle_.originalROWID.equals(originalROWID)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    } else if (address != null) {
      final query = handleBox.query(Handle_.address.equals(address)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    }
    return null;
  }

  static Handle merge(Handle handle1, Handle handle2) {
    handle1.id ??= handle2.id;
    handle1.originalROWID ??= handle2.originalROWID;
    handle1._color.value ??= handle2._color.value;
    handle1.country ??= handle2.country;
    handle1.formattedAddress ??= handle2.formattedAddress;
    if (isNullOrEmpty(handle1.defaultPhone)!) {
      handle1.defaultPhone = handle2.defaultPhone;
    }
    if (isNullOrEmpty(handle1.defaultEmail)!) {
      handle1.defaultEmail = handle2.defaultEmail;
    }

    return handle1;
  }

  /// Find a list of handles by the specified condition, or return all handles
  /// when no condition is specified
  static List<Handle> find({Condition<Handle>? cond}) {
    final query = handleBox.query(cond).build();
    return query.find();
  }

  Map<String, dynamic> toMap() => {
    "ROWID": id,
    "originalROWID": originalROWID,
    "address": address,
    "formattedAddress": formattedAddress,
    "country": country,
    "color": color,
    "defaultPhone": defaultPhone,
  };
}
