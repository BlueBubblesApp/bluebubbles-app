import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:flutter/foundation.dart';
import './chat.dart';

@Entity()
class Handle {
  int? id;
  int? originalROWID;
  @Unique()
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
    if (kIsWeb) return this;
    Handle? existing = Handle.findOne(address: this.address);
    if (existing != null) {
      this.id = existing.id;
    }
    try {
      handleBox.put(this);
    } on UniqueViolationException catch (_) {}

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
    if (kIsWeb) return null;
    if (originalROWID != null) {
      final query = handleBox.query(Handle_.originalROWID.equals(originalROWID)).build();
      query..limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    } else {
      final query = handleBox.query(Handle_.address.equals(address!)).build();
      query..limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    }
  }

  static List<Handle> find() {
    return handleBox.getAll();
  }

  static List<Chat> getChats(Handle handle) {
    if (kIsWeb) return [];
    final chatIds = chJoinBox.getAll().where((element) => element.handleId == handle.id).map((e) => e.chatId);
    final chats = chatBox.getAll().where((element) => chatIds.contains(element.id)).toList();
    return chats;
  }

  static void flush() {
    if (kIsWeb) return;
    handleBox.removeAll();
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
