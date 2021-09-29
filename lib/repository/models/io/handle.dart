import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import './chat.dart';

@Entity()
class Handle {
  int? id;
  int? originalROWID;
  @Unique()
  String address;
  String? country;
  final RxnString _color = RxnString();

  String? get color => _color.value;

  set color(String? val) => _color.value = val;
  String? defaultPhone;
  String? uncanonicalizedId;

  Handle({
    this.id,
    this.originalROWID,
    this.address = "",
    this.country,
    String? handleColor,
    this.defaultPhone,
    this.uncanonicalizedId,
  }) {
    color = handleColor;
  }

  factory Handle.fromMap(Map<String, dynamic> json) {
    var data = Handle(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      originalROWID: json.containsKey("originalROWID") ? json["originalROWID"] : null,
      address: json["address"],
      country: json.containsKey("country") ? json["country"] : null,
      handleColor: json.containsKey("color") ? json["color"] : null,
      defaultPhone: json['defaultPhone'],
      uncanonicalizedId: json.containsKey("uncanonicalizedId") ? json["uncanonicalizedId"] : null,
    );

    // Adds fallback getter for the ID
    data.id ??= json.containsKey("id") ? json["id"] : null;

    return data;
  }

  Handle save() {
    if (kIsWeb) return this;
    store.runInTransaction(TxMode.write, () {
      Handle? existing = Handle.findOne(address: address);
      if (existing != null) {
        id = existing.id;
      }
      try {
        handleBox.put(this);
      } on UniqueViolationException catch (_) {}
    });
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

  static Handle? findOne({int? originalROWID, String? address}) {
    if (kIsWeb) return null;
    if (originalROWID != null) {
      final query = handleBox.query(Handle_.originalROWID.equals(originalROWID)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    } else {
      final query = handleBox.query(Handle_.address.equals(address!)).build();
      query.limit = 1;
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
    return store.runInTransaction(TxMode.read, () {
      final chatIdQuery = chJoinBox.query(ChatHandleJoin_.handleId.equals(handle.id!)).build();
      final chatIds = chatIdQuery.property(ChatHandleJoin_.chatId).find();
      chatIdQuery.close();
      final chatQuery = chatBox.query(Chat_.id.oneOf(chatIds)).build();
      final chats = chatQuery.find();
      chatQuery.close();
      return chats;
    });
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
