import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/theme_entry.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class ThemeObject {
  int id;
  String name;
  bool selectedLightTheme;
  bool selectedDarkTheme;
  ThemeData data;
  List<ThemeEntry> entries = [];

  ThemeObject({
    this.id,
    this.name,
    this.selectedLightTheme,
    this.selectedDarkTheme,
    this.data,
  });
  factory ThemeObject.fromMap(Map<String, dynamic> json) {
    return ThemeObject(
      id: json["ROWID"],
      name: json["name"],
      selectedLightTheme: json["selectedLightTheme"] == 1,
      selectedDarkTheme: json["selectedDarkTheme"] == 1,
    );
  }

  List<ThemeEntry> toEntries() => [
        ThemeEntry.fromStyle(ThemeColors.Headline1, data.textTheme.headline1),
        ThemeEntry.fromStyle(ThemeColors.Headline2, data.textTheme.headline2),
        ThemeEntry.fromStyle(ThemeColors.Bodytext1, data.textTheme.bodyText1),
        ThemeEntry.fromStyle(ThemeColors.Bodytext2, data.textTheme.bodyText2),
        ThemeEntry.fromStyle(ThemeColors.Subtitle1, data.textTheme.subtitle1),
        ThemeEntry.fromStyle(ThemeColors.Subtitle2, data.textTheme.subtitle2),
        ThemeEntry(
            name: ThemeColors.AccentColor,
            color: data.accentColor,
            isFont: false),
        ThemeEntry(
            name: ThemeColors.DividerColor,
            color: data.dividerColor,
            isFont: false),
        ThemeEntry(
            name: ThemeColors.BackgroundColor,
            color: data.backgroundColor,
            isFont: false),
      ];

  Future<ThemeObject> save(
      {bool updateIfAbsent = true, Database database}) async {
    assert(this.data != null);
    final Database db =
        database != null ? database : await DBProvider.db.database;

    if (entries.isEmpty) {
      entries = this.toEntries();
    }

    ThemeObject existing =
        await ThemeObject.findOne({"name": this.name}, database: database);
    if (existing != null) {
      this.id = existing.id;
    }

    if (this.selectedDarkTheme) {
      await db.update("themes", {"selectedDarkTheme": 0});
    } else if (this.selectedLightTheme) {
      await db.update("themes", {"selectedLightTheme": 0});
    }
    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = this.toMap();
      if (map.containsKey("ROWID")) {
        map.remove("ROWID");
      }

      this.id = await db.insert("themes", map);
    } else if (updateIfAbsent) {
      await this.update(database: database);
    }

    for (ThemeEntry entry in this.entries) {
      await entry.save(this, database: database);
    }

    return this;
  }

  Future<ThemeObject> update({Database database}) async {
    final Database db =
        database != null ? database : await DBProvider.db.database;

    // If it already exists, update it
    if (this.id != null) {
      await db.update(
          "themes",
          {
            "name": this.name,
            "selectedLightTheme": this.selectedLightTheme ? 1 : 0,
            "selectedDarkTheme": this.selectedDarkTheme ? 1 : 0,
          },
          where: "ROWID = ?",
          whereArgs: [this.id]);
    } else {
      await this.save(updateIfAbsent: false, database: database);
    }

    return this;
  }

  static Future<ThemeObject> getLightTheme() async {
    List<ThemeObject> themes = await ThemeObject.getThemes();
    ThemeObject theme =
        themes.firstWhere((element) => element.selectedLightTheme);
    await theme.fetchData();
    return theme;
  }

  static Future<ThemeObject> getDarkTheme() async {
    List<ThemeObject> themes = await ThemeObject.getThemes();
    ThemeObject theme =
        themes.firstWhere((element) => element.selectedDarkTheme);
    await theme.fetchData();
    return theme;
  }

  static Future<void> setSelectedTheme(int light, int dark) async {
    final Database db = await DBProvider.db.database;
    await db
        .update("themes", {"selectedLightTheme": 0, "selectedDarkTheme": 0});
    await db.update("themes", {"selectedLightTheme": 1},
        where: "ROWID = ?", whereArgs: [light]);
    await db.update("themes", {"selectedDarkTheme": 1},
        where: "ROWID = ?", whereArgs: [dark]);
  }

  static Future<ThemeObject> findOne(Map<String, dynamic> filters,
      {Database database}) async {
    final Database db =
        database != null ? database : await DBProvider.db.database;

    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));
    var res = await db.query("themes",
        where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }

    return ThemeObject.fromMap(res.elementAt(0));
  }

  static Future<List<ThemeObject>> getThemes({Database database}) async {
    final Database db =
        database != null ? database : await DBProvider.db.database;
    var res = await db.query("themes");
    if (res.isEmpty) return [];

    return (res.isNotEmpty)
        ? res.map((c) => ThemeObject.fromMap(c)).toList()
        : [];
  }

  Future<List<ThemeEntry>> fetchData() async {
    final Database db = await DBProvider.db.database;

    var res = await db.rawQuery(
        "SELECT"
        " theme_values.ROWID as ROWID,"
        " theme_values.name as name,"
        " theme_values.color as color,"
        " theme_values.isFont as isFont,"
        " theme_values.fontSize as fontSize"
        " FROM themes"
        " JOIN theme_value_join AS tvj ON themes.ROWID = tvj.themeId"
        " JOIN theme_values ON theme_values.ROWID = tvj.themeValueId"
        " WHERE themes.ROWID = ?;",
        [this.id]);
    this.entries =
        (res.isNotEmpty) ? res.map((t) => ThemeEntry.fromMap(t)).toList() : [];
    return this.entries;
  }

  Map<String, dynamic> toMap() => {
        "ROWID": this.id,
        "name": this.name,
        "selectedLightTheme": this.selectedLightTheme ? 1 : 0,
        "selectedDarkTheme": this.selectedDarkTheme ? 1 : 0,
      };

  ThemeData get themeData {
    assert(entries.length == 9);
    Map<String, ThemeEntry> data = {};
    for (ThemeEntry entry in entries) {
      if (entry.name == ThemeColors.Headline1) {
        data[ThemeColors.Headline1] = entry;
      } else if (entry.name == ThemeColors.Headline2) {
        data[ThemeColors.Headline2] = entry;
      } else if (entry.name == ThemeColors.Bodytext1) {
        data[ThemeColors.Bodytext1] = entry;
      } else if (entry.name == ThemeColors.Bodytext2) {
        data[ThemeColors.Bodytext2] = entry;
      } else if (entry.name == ThemeColors.Subtitle1) {
        data[ThemeColors.Subtitle1] = entry;
      } else if (entry.name == ThemeColors.Subtitle2) {
        data[ThemeColors.Subtitle2] = entry;
      } else if (entry.name == ThemeColors.AccentColor) {
        data[ThemeColors.AccentColor] = entry;
      } else if (entry.name == ThemeColors.DividerColor) {
        data[ThemeColors.DividerColor] = entry;
      } else if (entry.name == ThemeColors.BackgroundColor) {
        data[ThemeColors.BackgroundColor] = entry;
      }
    }

    return ThemeData(
      textTheme: TextTheme(
        headline1: data[ThemeColors.Headline1].style,
        headline2: data[ThemeColors.Headline2].style,
        bodyText1: data[ThemeColors.Bodytext1].style,
        bodyText2: data[ThemeColors.Bodytext2].style,
        subtitle1: data[ThemeColors.Subtitle1].style,
        subtitle2: data[ThemeColors.Subtitle2].style,
      ),
      accentColor: data[ThemeColors.AccentColor].style,
      dividerColor: data[ThemeColors.DividerColor].style,
      backgroundColor: data[ThemeColors.BackgroundColor].style,
    );
  }
}
