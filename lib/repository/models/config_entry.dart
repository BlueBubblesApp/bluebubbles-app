import 'dart:async';

import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/helpers/db_converter.dart';
import 'package:sqflite/sqflite.dart';

class ConfigEntry<T> {
  int? id;
  String? name;
  T? value;
  Type? type;

  ConfigEntry({
    this.id,
    this.name,
    this.value,
    this.type,
  });

  static ConfigEntry fromMap(Map<String, dynamic> json) {
    String _type = json["type"] ?? "";
    Type t = DBConverter.getType(_type) ?? String;
    if (t == bool) {
      return ConfigEntry<bool>(
        id: json["ROWID"],
        name: json["name"],
        value: DBConverter.getValue(json["value"], _type),
        type: t,
      );
    } else if (t == double) {
      return ConfigEntry<double>(
        id: json["ROWID"],
        name: json["name"],
        value: DBConverter.getValue(json["value"], _type),
        type: t,
      );
    } else if (t == int) {
      return ConfigEntry<int>(
        id: json["ROWID"],
        name: json["name"],
        value: DBConverter.getValue(json["value"], _type),
        type: t,
      );
    } else {
      return ConfigEntry<String>(
        id: json["ROWID"],
        name: json["name"],
        value: DBConverter.getValue(json["value"], _type),
        type: t,
      );
    }
  }

  Future<ConfigEntry> save(String table, {bool updateIfAbsent = true, Database? database}) async {
    final Database? db = database ?? await DBProvider.db.database;

    // Try to find an existing ConfigEntry before saving it
    ConfigEntry? existing = await ConfigEntry.findOne(table, {"name": name}, database: database);
    if (existing != null) {
      id = existing.id;
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = toMap();
      map.remove("ROWID");
      try {
        id = await db!.insert(table, map);
      } catch (e) {
        id = null;
      }
    } else if (updateIfAbsent) {
      await update(table, database: database);
    }

    return this;
  }

  Future<ConfigEntry> update(String table, {Database? database}) async {
    final Database? db = database ?? await DBProvider.db.database;

    // If it already exists, update it
    if (id != null) {
      await db!.update(
          table,
          {
            "name": name,
            "value": DBConverter.getString(value),
            "type": DBConverter.getStringType(type),
          },
          where: "ROWID = ?",
          whereArgs: [id]);
    } else {
      await save(table, updateIfAbsent: false, database: database);
    }

    return this;
  }

  static Future<ConfigEntry?> findOne(String table, Map<String, dynamic> filters, {Database? database}) async {
    final Database? db = database ?? await DBProvider.db.database;
    if (db == null) return null;
    List<String> whereParams = [];
    for (var filter in filters.keys) {
      whereParams.add('$filter = ?');
    }
    List<dynamic> whereArgs = [];
    for (var filter in filters.values) {
      whereArgs.add(filter);
    }
    var res = await db.query(table, where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return fromMap(res.first);
  }

  Map<String, dynamic> toMap() =>
      {"ROWID": id, "name": name, "value": DBConverter.getString(value), "type": DBConverter.getStringType(type)};
}
