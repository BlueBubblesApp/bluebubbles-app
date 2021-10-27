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

  Future<Handle> save([bool updateIfAbsent = false]) async {
    final Database? db = await DBProvider.db.database;

    // Try to find an existing handle before saving it
    Handle? existing = await Handle.findOne({"address": address});
    if (existing != null) {
      id = existing.id;
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = toMap();
      map.remove("ROWID");
      try {
        id = await db?.insert("handle", map);
      } catch (e) {
        id = null;
      }
    } else if (updateIfAbsent) {
      await update();
    }

    return this;
  }

  Future<Handle> update() async {
    final Database? db = await DBProvider.db.database;

    // If it already exists, update it
    if (id != null) {
      Map<String, dynamic> params = {
        "address": address,
        "country": country,
        "color": color,
        "defaultPhone": defaultPhone,
        "uncanonicalizedId": uncanonicalizedId
      };

      if (originalROWID != null) {
        params["originalROWID"] = originalROWID;
      }

      await db?.update("handle", params, where: "ROWID = ?", whereArgs: [id]);
    } else {
      await save(false);
    }

    return this;
  }

  Future<Handle> updateColor(String? newColor) async {
    final Database? db = await DBProvider.db.database;
    if (id == null) return this;

    await db?.update("handle", {"color": newColor}, where: "ROWID = ?", whereArgs: [id]);

    return this;
  }

  Future<Handle> updateDefaultPhone(String newPhone) async {
    final Database? db = await DBProvider.db.database;
    if (id == null) return this;

    await db?.update("handle", {"defaultPhone": newPhone}, where: "ROWID = ?", whereArgs: [id]);

    return this;
  }

  static Future<Handle?> findOne(Map<String, dynamic> filters) async {
    final Database? db = await DBProvider.db.database;
    if (db == null) return null;
    List<String> whereParams = [];
    for (var filter in filters.keys) {
      whereParams.add('$filter = ?');
    }
    List<dynamic> whereArgs = [];
    for (var filter in filters.values) {
      whereArgs.add(filter);
    }
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
    for (var filter in filters.keys) {
      whereParams.add('$filter = ?');
    }
    List<dynamic> whereArgs = [];
    for (var filter in filters.values) {
      whereArgs.add(filter);
    }
    var res = await db.query("handle",
        where: (whereParams.isNotEmpty) ? whereParams.join(" AND ") : null,
        whereArgs: (whereArgs.isNotEmpty) ? whereArgs : null);

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
