import 'package:bluebubbles/database/io/contact_v2.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart' show HandleLookupKey;
import 'package:bluebubbles/services/services.dart';
import 'package:faker/faker.dart';
import 'package:get/get.dart';

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

  // Web has no ObjectBox relations; expose empty list for API compatibility.
  List<ContactV2> get contacts => [];

  String? color;

  String get displayName {
    if (address.startsWith("urn:biz")) return "Business";
    return address.contains("@") ? address : (formattedAddress ?? address);
  }

  String? get initials {
    if (address.startsWith("urn:biz")) return null;
    final parts = displayName.trim().split(RegExp(r'[ \-_]'));
    if (parts.length == 1) return parts[0].firstAlpha;

    final firstPart = parts.first.firstAlpha ?? '';
    final secondPart = parts[1].firstAlpha ?? '';

    return (firstPart + secondPart).isEmpty ? null : firstPart + secondPart;
  }

  Handle({
    this.id,
    this.originalROWID,
    this.address = "",
    this.service = "iMessage",
    this.uniqueAddressAndService = "",
    this.formattedAddress,
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
        originalROWID: json["originalROWID"],
        address: json["address"],
        service: json["service"] ?? "iMessage",
        uniqueAddressAndService: json["uniqueAddrAndService"] ?? "${json["address"]}/${json["service"] ?? "iMessage"}",
        formattedAddress: json["formattedAddress"],
        country: json["country"],
        color: json["color"],
        defaultPhone: json['defaultPhone'],
      );

  Handle save({bool updateColor = false}) {
    return this;
  }

  static List<Handle> bulkSave(List<Handle> handles, {bool matchOnOriginalROWID = false}) {
    return [];
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
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    return ChatsSvc.webCachedHandles.firstWhereOrNull((e) => originalROWID != null
        ? e.originalROWID == originalROWID
        : e.uniqueAddressAndService == "${addressAndService?.address}/${addressAndService?.service}");
  }

  static List<Handle> find() {
    return [];
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
