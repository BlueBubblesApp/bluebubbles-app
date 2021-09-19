import 'package:bluebubbles/repository/models/html/chat.dart';

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
    var data = new Handle(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      originalROWID: json.containsKey("originalROWID") ? json["originalROWID"] : null,
      address: json["address"],
      country: json.containsKey("country") ? json["country"] : null,
      color: json.containsKey("color") ? json["color"] : null,
      defaultPhone: json['defaultPhone'],
      uncanonicalizedId: json.containsKey("uncanonicalizedId") ? json["uncanonicalizedId"] : null,
    );

    // Adds fallback getter for the ID
    if (data.id == null) {
      data.id = json.containsKey("id") ? json["id"] : null;
    }

    return data;
  }

  Handle save() {
    return this;
  }

  Handle updateColor(String? newColor) {
    this.color = newColor;
    this.save();
    return this;
  }

  Handle updateDefaultPhone(String newPhone) {
    this.defaultPhone = newPhone;
    this.save();
    return this;
  }

  static Handle? findOne({int? originalROWID, String? address}) {
    return null;
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
