import 'dart:async';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/theme_object.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class ThemeEntry {
  int? id;
  int? themeId;
  String? name;
  Color? color;
  bool? isFont;
  int? fontSize;
  int? fontWeight;

  ThemeEntry({
    this.id,
    this.themeId,
    this.name,
    this.color,
    this.isFont,
    this.fontSize,
    this.fontWeight,
  });

  factory ThemeEntry.fromMap(Map<String, dynamic> json) {
    return ThemeEntry(
      id: json["ROWID"],
      themeId: json["themeId"],
      name: json["name"],
      color: HexColor(json["color"]),
      isFont: json["isFont"] == 1,
      fontSize: json["fontSize"],
      fontWeight: json["fontWeight"],
    );
  }

  factory ThemeEntry.fromStyle(String title, TextStyle style) {
    return ThemeEntry(
      color: style.color,
      name: title,
      isFont: true,
      fontSize: style.fontSize != null ? style.fontSize!.toInt() : 14,
      fontWeight: FontWeight.values.indexOf(style.fontWeight ?? FontWeight.w400) + 1,
    );
  }

  dynamic get style => isFont!
      ? TextStyle(
          color: color,
          fontWeight: fontWeight != null ? FontWeight.values[fontWeight! - 1] : FontWeight.normal,
          fontSize: fontSize?.toDouble(),
        )
      : color;

  Future<ThemeEntry> save(ThemeObject theme, {bool updateIfAbsent = true}) async {
    final Database? db = await DBProvider.db.database;

    //assert(theme.id != null);
    themeId = theme.id;

    // Try to find an existing ConfigEntry before saving it
    ThemeEntry? existing = await ThemeEntry.findOne({"name": name, "themeId": themeId});
    if (existing != null) {
      id = existing.id;
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = toMap();
      map.remove("ROWID");
      try {
        id = (await db?.insert("theme_values", map)) ?? id;
      } catch (e) {
        id = null;
      }

      if (id != null && theme.id != null) {
        await db?.insert("theme_value_join", {"themeValueId": id, "themeId": theme.id});
      }
    } else if (updateIfAbsent) {
      await update(theme);
    }

    return this;
  }

  Future<ThemeEntry> update(ThemeObject theme) async {
    final Database? db = await DBProvider.db.database;

    // If it already exists, update it
    if (id != null) {
      await db?.update(
          "theme_values",
          {
            "name": name,
            "color": color!.value.toRadixString(16),
            "isFont": isFont! ? 1 : 0,
            "fontSize": fontSize,
            "fontWeight": fontWeight,
          },
          where: "ROWID = ?",
          whereArgs: [id]);
    } else {
      await save(theme, updateIfAbsent: false);
    }

    return this;
  }

  static Future<ThemeEntry?> findOne(Map<String, dynamic> filters, {Database? database}) async {
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
    var res = await db.query("theme_values", where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return ThemeEntry.fromMap(res.first);
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "name": name,
        "themeId": themeId,
        "color": color!.value.toRadixString(16),
        "isFont": isFont! ? 1 : 0,
        "fontSize": fontSize,
        "fontWeight": fontWeight,
      };
}
