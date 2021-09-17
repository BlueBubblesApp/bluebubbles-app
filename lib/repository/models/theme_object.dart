import 'dart:async';
import 'dart:core';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/theme_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:objectbox/objectbox.dart';


@Entity()
class ThemeObject {
  int? id;
  @Unique()
  String? name;
  bool selectedLightTheme = false;
  bool selectedDarkTheme = false;
  bool gradientBg = false;
  bool previousLightTheme = false;
  bool previousDarkTheme = false;
  ThemeData? data;
  List<ThemeEntry> entries = [];

  ThemeObject({
    this.id,
    this.name,
    this.selectedLightTheme = false,
    this.selectedDarkTheme = false,
    this.gradientBg = false,
    this.previousLightTheme = false,
    this.previousDarkTheme = false,
    this.data,
  });
  factory ThemeObject.fromData(ThemeData data, String name, {bool gradientBg = false}) {
    ThemeObject object = new ThemeObject(
      data: data.copyWith(),
      name: name,
      gradientBg: gradientBg,
    );
    object.entries = object.toEntries();

    return object;
  }

  factory ThemeObject.fromMap(Map<String, dynamic> json) {
    return ThemeObject(
      id: json["ROWID"],
      name: json["name"],
      selectedLightTheme: json["selectedLightTheme"] == 1,
      selectedDarkTheme: json["selectedDarkTheme"] == 1,
      gradientBg: json["gradientBg"] == 1,
      previousLightTheme: json["previousLightTheme"] == 1,
      previousDarkTheme: json["previousDarkTheme"] == 1,
    );
  }

  bool get isPreset => this.name == "OLED Dark" || this.name == "Bright White" || this.name == "Nord Theme" || this.name == "Music Theme (Light)" || this.name == "Music Theme (Dark)";

  List<ThemeEntry> toEntries() => [
        ThemeEntry.fromStyle(ThemeColors.Headline1, data!.textTheme.headline1!),
        ThemeEntry.fromStyle(ThemeColors.Headline2, data!.textTheme.headline2!),
        ThemeEntry.fromStyle(ThemeColors.Bodytext1, data!.textTheme.bodyText1!),
        ThemeEntry.fromStyle(ThemeColors.Bodytext2, data!.textTheme.bodyText2!),
        ThemeEntry.fromStyle(ThemeColors.Subtitle1, data!.textTheme.subtitle1!),
        ThemeEntry.fromStyle(ThemeColors.Subtitle2, data!.textTheme.subtitle2!),
        ThemeEntry(name: ThemeColors.AccentColor, color: data!.accentColor, isFont: false),
        ThemeEntry(name: ThemeColors.DividerColor, color: data!.dividerColor, isFont: false),
        ThemeEntry(name: ThemeColors.BackgroundColor, color: data!.backgroundColor, isFont: false),
        ThemeEntry(name: ThemeColors.PrimaryColor, color: data!.primaryColor, isFont: false),
      ];

  Future<ThemeObject> save({bool updateIfAbsent = true}) async {
    assert(this.data != null);
    /*final Database? db = await DBProvider.db.database;

    if (entries.isEmpty) {
      entries = this.toEntries();
    }

    ThemeObject? existing = await ThemeObject.findOne({"name": this.name});
    if (existing != null) {
      this.id = existing.id;
    }

    // If it already exists, update it
    if (existing == null) {
      // Remove the ID from the map for inserting
      var map = this.toMap();
      if (map.containsKey("ROWID")) {
        map.remove("ROWID");
      }

      this.id = (await db?.insert("themes", map)) ?? id;
    } else if (updateIfAbsent) {
      await this.update();
    }*/
    try {
      themeObjectBox.put(this);
    } on UniqueViolationException catch (_) {}

    if (this.isPreset && !this.name!.contains("Music")) return this;
    for (ThemeEntry entry in this.entries) {
      await entry.save(this);
    }

    return this;
  }

  Future<void> delete() async {
   /* if (this.isPreset) return;
    final Database? db = await DBProvider.db.database;

    if (this.id == null) await this.save(updateIfAbsent: false);*/
    await this.fetchData();
    themeEntryBox.removeMany(this.entries.map((e) => e.id!).toList());
    final query = tvJoinBox.query(ThemeValueJoin_.themeId.equals(this.id!)).build();
    tvJoinBox.remove(query.find().first.themeId);
    query.close();
    themeObjectBox.remove(this.id!);
    /*await db?.delete("theme_value_join", where: "themeId = ?", whereArgs: [this.id]);
    await db?.delete("themes", where: "ROWID = ?", whereArgs: [this.id]);*/
  }

  Future<ThemeObject> update() async {
    /*final Database? db = await DBProvider.db.database;

    // If it already exists, update it
    if (this.id != null) {
      await db?.update(
          "themes",
          {
            "name": this.name,
            "selectedLightTheme": this.selectedLightTheme ? 1 : 0,
            "selectedDarkTheme": this.selectedDarkTheme ? 1 : 0,
            "gradientBg": this.gradientBg ? 1 : 0,
            "previousLightTheme": this.previousLightTheme ? 1 : 0,
            "previousDarkTheme": this.previousDarkTheme ? 1 : 0,
          },
          where: "ROWID = ?",
          whereArgs: [this.id]);
    } else {
      await this.save(updateIfAbsent: false);
    }*/
    this.save();

    return this;
  }

  static Future<ThemeObject> getLightTheme() async {
    List<ThemeObject> res = await ThemeObject.getThemes();
    List<ThemeObject> themes = res.where((element) => element.selectedLightTheme).toList();
    if (themes.isEmpty) {
      return Themes.themes[1];
    }
    ThemeObject theme = themes.first;
    await theme.fetchData();
    return theme;
  }

  static Future<ThemeObject> getDarkTheme() async {
    List<ThemeObject> res = await ThemeObject.getThemes();
    List<ThemeObject> themes = res.where((element) => element.selectedDarkTheme).toList();
    if (themes.isEmpty) {
      return Themes.themes[0];
    }
    ThemeObject theme = themes.first;
    await theme.fetchData();
    return theme;
  }

  static Future<void> setSelectedTheme({int? light, int? dark}) async {
    if (light != null) {
      final query = themeObjectBox.query(ThemeObject_.selectedLightTheme.equals(true)).build();
      final result = query.find().first;
      query.close();
      result.selectedLightTheme = false;
      result.save();
      final lightTheme = themeObjectBox.get(light);
      lightTheme!.selectedLightTheme = true;
      lightTheme.save();
    }
    if (dark != null) {
      final query = themeObjectBox.query(ThemeObject_.selectedDarkTheme.equals(true)).build();
      final result = query.find().first;
      query.close();
      result.selectedDarkTheme = false;
      result.save();
      final darkTheme = themeObjectBox.get(dark);
      darkTheme!.selectedDarkTheme = true;
      darkTheme.save();
    }
  }

  static Future<ThemeObject?> findOne(
    Map<String, dynamic> filters,
  ) async {
    /*final Database? db = await DBProvider.db.database;
    if (db == null) return null;
    List<String> whereParams = [];
    filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
    List<dynamic> whereArgs = [];
    filters.values.forEach((filter) => whereArgs.add(filter));
    var res = await db.query("themes", where: whereParams.join(" AND "), whereArgs: whereArgs, limit: 1);

    if (res.isEmpty) {
      return null;
    }*/
    final query = themeObjectBox.query(ThemeObject_.name.equals(filters['name'])).build();
    query..limit = 1;
    final result = query.findFirst();
    query.close();

    return result;
  }

  static Future<List<ThemeObject>> getThemes() async {
    /*final Database? db = await DBProvider.db.database;
    if (db == null) return Themes.themes;
    var res = await db.query("themes");
    if (res.isEmpty) return Themes.themes;*/
    final results = themeObjectBox.getAll();

    return (results.isNotEmpty) ? results.map((e) => e..fetchData()).toList() : Themes.themes;
  }

  Future<List<ThemeEntry>> fetchData() async {
    if (isPreset && !name!.contains("Music")) {
      if (name == "OLED Dark") {
        this.data = oledDarkTheme;
      } else if (name == "Bright White") {
        this.data = whiteLightTheme;
      } else if (name == "Nord Theme") {
        this.data = nordDarkTheme;
      }

      this.entries = this.toEntries();
      return this.entries;
    }
    //final Database? db = await DBProvider.db.database;
    final query = tvJoinBox.query(ThemeValueJoin_.themeId.equals(this.id!)).build();
    final themeEntryIds = query.property(ThemeValueJoin_.themeValueId).find();
    final themeEntries2 = themeEntryBox.getMany(themeEntryIds, growableResult: true);
    themeEntries2.retainWhere((element) => element != null);
    final themeEntries = List<ThemeEntry>.from(themeEntries2);
    /*if (db == null) return this.entries;
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
        [this.id]);*/
    if (name == "Music Theme (Light)" && themeEntries.isEmpty) {
      data = whiteLightTheme;
      entries = this.toEntries();
    } else if (name == "Music Theme (Dark)" && themeEntries.isEmpty) {
      data = oledDarkTheme;
      entries = this.toEntries();
    } else if (themeEntries.isNotEmpty) {
      this.entries = themeEntries;
      this.data = themeData;
    } else {
      this.entries = [];
      this.data = themeData;
    }
    return this.entries;
  }

  Map<String, dynamic> toMap() => {
        "ROWID": this.id,
        "name": this.name,
        "selectedLightTheme": this.selectedLightTheme ? 1 : 0,
        "selectedDarkTheme": this.selectedDarkTheme ? 1 : 0,
        "gradientBg": this.gradientBg ? 1 : 0,
        "previousLightTheme": this.previousLightTheme ? 1 : 0,
        "previousDarkTheme": this.previousDarkTheme ? 1 : 0,
      };

  ThemeData get themeData {
    assert(entries.length == ThemeColors.Colors.length);
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
      } else if (entry.name == ThemeColors.PrimaryColor) {
        data[ThemeColors.PrimaryColor] = entry;
      }
    }

    return ThemeData(
        textTheme: TextTheme(
          headline1: data[ThemeColors.Headline1]!.style,
          headline2: data[ThemeColors.Headline2]!.style,
          bodyText1: data[ThemeColors.Bodytext1]!.style,
          bodyText2: data[ThemeColors.Bodytext2]!.style,
          subtitle1: data[ThemeColors.Subtitle1]!.style,
          subtitle2: data[ThemeColors.Subtitle2]!.style,
        ),
        accentColor: data[ThemeColors.AccentColor]!.style,
        dividerColor: data[ThemeColors.DividerColor]!.style,
        backgroundColor: data[ThemeColors.BackgroundColor]!.style,
        primaryColor: data[ThemeColors.PrimaryColor]!.style);
  }

  static bool inDarkMode(BuildContext context) {
    return (AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark
        || (AdaptiveTheme.of(context).mode == AdaptiveThemeMode.system && SchedulerBinding.instance!.window.platformBrightness == Brightness.dark));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ThemeObject && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
