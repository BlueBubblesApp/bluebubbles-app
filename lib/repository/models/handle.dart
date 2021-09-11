import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:sqflite/sqflite.dart';

import './chat.dart';
import '../database.dart';

Handle handleFromJson(String str) {
  final jsonData = json.decode(str);
  return Handle.fromMap(jsonData);
}

String handleToJson(Handle data) {
  final dyn = data.toMap();
  return json.encode(dyn);
}

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

  Future<Handle> save([bool updateIfAbsent = false]) async {
    final Database? db = await DBProvider.db.database;

    // Try to find an existing handle before saving it
    Handle? existing = await Handle.findOne({"address": this.address});
    if (existing != null) {
      this.id = existing.id;
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = this.toMap();
      map.remove("ROWID");
      try {
        this.id = await db?.insert("handle", map);
      } catch (e) {
        this.id = null;
      }
    } else if (updateIfAbsent) {
      await this.update();
    }

    return this;
  }

  Future<Handle> update() async {
    final Database? db = await DBProvider.db.database;

    // If it already exists, update it
    if (this.id != null) {
      Map<String, dynamic> params = {
        "address": this.address,
        "country": this.country,
        "color": this.color,
        "defaultPhone": this.defaultPhone,
        "uncanonicalizedId": this.uncanonicalizedId
      };

      if (this.originalROWID != null) {
        params["originalROWID"] = this.originalROWID;
      }

      await db?.update("handle", params, where: "ROWID = ?", whereArgs: [this.id]);
    } else {
      await this.save(false);
    }

    return this;
  }

  Future<Handle> updateColor(String? newColor) async {
    final Database? db = await DBProvider.db.database;
    if (this.id == null) return this;

    await db?.update("handle", {"color": newColor}, where: "ROWID = ?", whereArgs: [this.id]);

    return this;
  }

  Future<Handle> updateDefaultPhone(String newPhone) async {
    final Database? db = await DBProvider.db.database;
    if (this.id == null) return this;

    await db?.update("handle", {"defaultPhone": newPhone}, where: "ROWID = ?", whereArgs: [this.id]);

    return this;
  }

  static Future<Handle?> findOne(Map<String, dynamic> filters) async {
    final Database? db = await DBProvider.db.database;
    if (db == null) return null;
    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));
    var res = await db.query("handle", where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return Handle.fromMap(res.elementAt(0));
  }

  static Future<List<Handle>> find([Map<String, dynamic> filters = const {}]) async {
    final Database? db = await DBProvider.db.database;
    if (db == null) return ChatBloc().cachedHandles;
    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));
    var res = await db.query("handle",
        where: (whereParams.length > 0) ? whereParams.join(" AND ") : null,
        whereArgs: (whereArgs.length > 0) ? whereArgs : null);

    return (res.isNotEmpty) ? res.map((c) => Handle.fromMap(c)).toList() : [];
  }

  static Future<List<Chat>> getChats(Handle handle) async {
    final Database? db = await DBProvider.db.database;
    if (db == null) return [];
    var res = await db.rawQuery(
        "SELECT"
        " chat.ROWID AS ROWID,"
        " chat.originalROWID AS originalROWID,"
        " chat.guid AS guid,"
        " chat.style AS style,"
        " chat.chatIdentifier AS chatIdentifier,"
        " chat.isArchived AS isArchived,"
        " chat.displayName AS displayName"
        " FROM handle"
        " JOIN chat_handle_join AS chj ON handle.ROWID = chj.handleId"
        " JOIN chat ON chat.ROWID = chj.chatId"
        " WHERE handle.address = ? OR handle.ROWID;",
        [handle.address, handle.id]);

    return (res.isNotEmpty) ? res.map((c) => Chat.fromMap(c)).toList() : [];
  }

  static flush() async {
    final Database? db = await DBProvider.db.database;
    await db?.delete("handle");
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
