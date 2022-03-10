import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/repository/models/html/chat.dart';
import 'package:collection/collection.dart';

class Handle {
  int? id;
  int? originalROWID;
  String address;
  String? country;
  String? color;
  String? defaultPhone;
  String? uncanonicalizedId;

  Handle({
    this.id,
    this.originalROWID,
    this.address = "",
    this.country,
    this.color,
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

  static Handle? findOne({int? id, int? originalROWID, String? address}) {
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    return ChatBloc().cachedHandles.firstWhereOrNull((e) => originalROWID != null ? e.originalROWID == originalROWID : e.address == address);
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
        "defaultPhone": defaultPhone,
        "uncanonicalizedId": uncanonicalizedId,
      };
}
