import 'package:bluebubbles/models/html/chat.dart';
import 'package:bluebubbles/models/html/contact.dart';
import 'package:bluebubbles/models/html/objectbox.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:faker/faker.dart';

class Handle {
  int? id;
  int? originalROWID;
  String address;
  String? formattedAddress;
  String? country;
  String? color;
  String? defaultEmail;
  String? defaultPhone;
  String? uncanonicalizedId;
  final String fakeName = faker.person.name();

  final contactRelation = ToOne<Contact>();
  Contact? webContact;

  Contact? get contact => webContact;
  String get displayName {
    if (ss.settings.redactedMode.value) {
      if (ss.settings.generateFakeContactNames.value) {
        return fakeName;
      } else if (ss.settings.hideContactInfo.value) {
        return "";
      }
    }
    if (contact != null) return contact!.displayName;
    return address.contains("@") ? address : (formattedAddress ?? address);
  }
  String? get initials {
    // Remove any numbers, certain symbols, and non-alphabet characters
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
    this.country,
    this.color,
    this.defaultEmail,
    this.defaultPhone,
    this.uncanonicalizedId,
  });

  factory Handle.fromMap(Map<String, dynamic> json) {
    var data = Handle(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      originalROWID: json.containsKey("originalROWID") ? json["originalROWID"] : null,
      address: json["address"],
      country: json.containsKey("country") ? json["country"] : null,
      color: json.containsKey("color") ? json["color"] : null,
      defaultEmail: json['defaultEmail'],
      defaultPhone: json['defaultPhone'],
      uncanonicalizedId: json.containsKey("uncanonicalizedId") ? json["uncanonicalizedId"] : null,
    );

    // Adds fallback getter for the ID
    data.id ??= json.containsKey("id") ? json["id"] : null;

    return data;
  }

  Handle save({updateColor = false}) {
    return this;
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
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    return chats.webCachedHandles.firstWhereOrNull((e) => originalROWID != null ? e.originalROWID == originalROWID : e.address == address);
  }

  static List<Handle> find() {
    return [];
  }

  static List<Chat> getChats(Handle handle) {
    return [];
  }

  static void flush() {
    return;
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "originalROWID": originalROWID,
        "address": address,
        "country": country,
        "color": color,
        "defaultEmail": defaultEmail,
        "defaultPhone": defaultPhone,
        "uncanonicalizedId": uncanonicalizedId,
      };
}
