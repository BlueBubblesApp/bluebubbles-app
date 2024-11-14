import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/html/contact.dart';
import 'package:bluebubbles/database/html/objectbox.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:faker/faker.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class Handle {
  int? id;
  int? originalROWID;
  String uniqueAddressAndService;
  String address;
  String? formattedAddress;
  String service;
  String? country;
  String? defaultEmail;
  String? defaultPhone;
  final String fakeName = faker.person.name();

  final contactRelation = ToOne<Contact>();
  Contact? webContact;

  final RxnString _color = RxnString();
  String? get color => _color.value;
  set color(String? val) => _color.value = val;

  Contact? get contact => webContact;
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
        .split(RegExp(r'[ \-_]'))
        .take(2)
        .map((e) => e.isEmpty ? '' : e[0].toUpperCase())
        .join('');
    return reduced.isEmpty ? null : reduced;
  }

  Handle({
    this.id,
    this.originalROWID,
    this.address = "",
    this.service = "iMessage",
    this.uniqueAddressAndService = "",
    this.formattedAddress,
    this.country,
    String? handleColor,
    this.defaultEmail,
    this.defaultPhone,
  }) {
    if (service.isEmpty) {
      service = 'iMessage';
    }
    if (uniqueAddressAndService.isEmpty) {
      uniqueAddressAndService = "$address/$service";
    }
    color = handleColor;
  }

  factory Handle.fromMap(Map<String, dynamic> json) => Handle(
    id: json["ROWID"] ?? json["id"],
    originalROWID: json["originalROWID"],
    address: json["address"],
    service: json["service"] ?? "iMessage",
    uniqueAddressAndService: json["uniqueAddrAndService"] ?? "${json["address"]}/${json["service"] ?? "iMessage"}",
    formattedAddress: json["formattedAddress"],
    country: json["country"],
    handleColor: json["color"],
    defaultPhone: json['defaultPhone'],
  );

  Handle save({updateColor = false}) {
    if (kIsWeb) return this;
    Database.runInTransaction(TxMode.write, () {
      Handle? existing;
      if (matchOnOriginalROWID) {
        existing = Handle.findOne(originalROWID: originalROWID);
      } else {
        existing = Handle.findOne(addressAndService: Tuple2(address, service));
      }

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
        id = Database.handles.put(this);
        if (contactRelation.target != null) {
          contactRelation.target!.save();
        }
      } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  static List<Handle> bulkSave(List<Handle> handles, {bool matchOnOriginalROWID = false}) {
    Database.runInTransaction(TxMode.write, () {
      for (Handle h in handles) {
        Handle? existing;
        if (matchOnOriginalROWID) {
          existing = Handle.findOne(originalROWID: h.originalROWID);
        } else {
          existing = Handle.findOne(addressAndService: Tuple2(h.address, h.service));
        }

        if (existing != null) {
          h.id = existing.id;
        } else {
          h.contactRelation.target ??= cs.matchHandleToContact(h);
        }
      }

      List<int> insertedIds = Database.handles.putMany(handles);
      for (int i = 0; i < insertedIds.length; i++) {
        handles[i].id = insertedIds[i];
        if (handles[i].contactRelation.target != null) {
          handles[i].contactRelation.target!.save();
        }
      }
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

  static Handle? findOne({int? id, int? originalROWID, Tuple2<String, String>? addressAndService}) {
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
      final query = Database.handles.query(Handle_.address.equals(addressAndService.item1) & Handle_.service.equals(addressAndService.item2)).build();
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
    if (isNullOrEmpty(handle1.defaultPhone)) {
      handle1.defaultPhone = handle2.defaultPhone;
    }
    if (isNullOrEmpty(handle1.defaultEmail)) {
      handle1.defaultEmail = handle2.defaultEmail;
    }

    return handle1;
  }

  Map<String, dynamic> toMap({bool includeObjects = false}) {

    final output = {
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

    if (includeObjects) {
      output['contact'] = contact?.toMap();
      output['contactRelation'] = contactRelation.target?.toMap();
    }

    return output;
  }
}
