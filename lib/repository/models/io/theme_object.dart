import 'dart:core';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/io/theme_entry.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// (needed when generating objectbox model code)
// ignore: unnecessary_import
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

  @Backlink('themeObject')
  final themeEntries = ToMany<ThemeEntry>();

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
    ThemeObject object = ThemeObject(
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

  bool get isPreset =>
      name == "OLED Dark" ||
      name == "Bright White" ||
      name == "Nord Theme" ||
      name == "Music Theme (Light)" ||
      name == "Music Theme (Dark)";

  List<ThemeEntry> toEntries() => [
        ThemeEntry.fromStyle(ThemeColors.Headline1, data!.textTheme.headline1!),
        ThemeEntry.fromStyle(ThemeColors.Headline2, data!.textTheme.headline2!),
        ThemeEntry.fromStyle(ThemeColors.Bodytext1, data!.textTheme.bodyText1!),
        ThemeEntry.fromStyle(ThemeColors.Bodytext2, data!.textTheme.bodyText2!),
        ThemeEntry.fromStyle(ThemeColors.Subtitle1, data!.textTheme.subtitle1!),
        ThemeEntry.fromStyle(ThemeColors.Subtitle2, data!.textTheme.subtitle2!),
        ThemeEntry(name: ThemeColors.AccentColor, color: data!.colorScheme.secondary, isFont: false),
        ThemeEntry(name: ThemeColors.DividerColor, color: data!.dividerColor, isFont: false),
        ThemeEntry(name: ThemeColors.BackgroundColor, color: data!.backgroundColor, isFont: false),
        ThemeEntry(name: ThemeColors.PrimaryColor, color: data!.primaryColor, isFont: false),
      ];

  ThemeObject save({bool updateIfNotAbsent = true}) {
    store.runInTransaction(TxMode.write, () {
      if (data == null) {
        fetchData();
      }
      if (entries.isEmpty) {
        entries = toEntries();
      }
      ThemeObject? existing = ThemeObject.findOne(name!);
      if (existing != null) {
        id = existing.id;
      }
      try {
        if (id != null && existing != null && updateIfNotAbsent) {
          id = themeObjectBox.put(this);
        } else if (id == null || existing == null) {
          id = themeObjectBox.put(this);
        }
      } on UniqueViolationException catch (_) {}

      if (isPreset && !name!.contains("Music")) return this;
      for (ThemeEntry entry in entries) {
        entry.save(this);
      }
    });
    return this;
  }

  void delete() {
    if (kIsWeb || isPreset || id == null) return;
    store.runInTransaction(TxMode.write, () {
      fetchData();
      themeEntryBox.removeMany(entries.map((e) => e.id!).toList());
      themeObjectBox.remove(id!);
    });
  }

  static ThemeObject getLightTheme({bool fetchData = true}) {
    final query = themeObjectBox.query(ThemeObject_.selectedLightTheme.equals(true)).build();
    query.limit = 1;
    final result = query.find().firstOrNull;
    if (result == null) {
      return Themes.themes[1];
    }
    if (fetchData) {
      result.fetchData();
    }
    return result;
  }

  static ThemeObject getDarkTheme({bool fetchData = true}) {
    final query = themeObjectBox.query(ThemeObject_.selectedDarkTheme.equals(true)).build();
    query.limit = 1;
    final result = query.find().firstOrNull;
    if (result == null) {
      return Themes.themes[0];
    }
    if (fetchData) {
      result.fetchData();
    }
    return result;
  }

  static void setSelectedTheme({int? light, int? dark}) {
    if (light != null) {
      store.runInTransaction(TxMode.write, () {
        final query = themeObjectBox.query(ThemeObject_.selectedLightTheme.equals(true)).build();
        final result = query.findFirst();
        query.close();
        result?.selectedLightTheme = false;
        result?.save();
        final lightTheme = themeObjectBox.get(light);
        lightTheme!.selectedLightTheme = true;
        lightTheme.save();
      });
    }
    if (dark != null) {
      store.runInTransaction(TxMode.write, () {
        final query = themeObjectBox.query(ThemeObject_.selectedDarkTheme.equals(true)).build();
        final result = query.findFirst();
        query.close();
        result?.selectedDarkTheme = false;
        result?.save();
        final darkTheme = themeObjectBox.get(dark);
        darkTheme!.selectedDarkTheme = true;
        darkTheme.save();
      });
    }
  }

  static ThemeObject? findOne(String name) {
    if (kIsWeb) return null;
    return store.runInTransaction(TxMode.read, () {
      final query = themeObjectBox.query(ThemeObject_.name.equals(name)).build();
      query.limit = 1;
      final result = query.findFirst();
      result?.fetchData();
      query.close();
      return result;
    });
  }

  static List<ThemeObject> getThemes() {
    if (kIsWeb) return Themes.themes;
    final results = themeObjectBox.getAll();
    return (results.isNotEmpty) ? results.map((e) => e..fetchData()).toList() : Themes.themes;
  }

  List<ThemeEntry> fetchData() {
    if (isPreset && !name!.contains("Music")) {
      if (name == "OLED Dark") {
        data = oledDarkTheme;
      } else if (name == "Bright White") {
        data = whiteLightTheme;
      } else if (name == "Nord Theme") {
        data = nordDarkTheme;
      }

      entries = toEntries();
      return entries;
    }
    if (kIsWeb) return entries;
    final themeEntries = List<ThemeEntry>.from(this.themeEntries);
    if (name == "Music Theme (Light)" && themeEntries.isEmpty) {
      data = whiteLightTheme;
      entries = toEntries();
    } else if (name == "Music Theme (Dark)" && themeEntries.isEmpty) {
      data = oledDarkTheme;
      entries = toEntries();
    } else if (themeEntries.isNotEmpty) {
      entries = themeEntries;
      data = themeData;
    } else {
      entries = [];
      data = themeData;
    }
    return entries;
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "name": name,
        "selectedLightTheme": selectedLightTheme ? 1 : 0,
        "selectedDarkTheme": selectedDarkTheme ? 1 : 0,
        "gradientBg": gradientBg ? 1 : 0,
        "previousLightTheme": previousLightTheme ? 1 : 0,
        "previousDarkTheme": previousDarkTheme ? 1 : 0,
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
        colorScheme: ColorScheme.fromSwatch(
          accentColor: data[ThemeColors.AccentColor]!.style,
          backgroundColor: data[ThemeColors.BackgroundColor]!.style,
        ),
        dividerColor: data[ThemeColors.DividerColor]!.style,
        backgroundColor: data[ThemeColors.BackgroundColor]!.style,
        primaryColor: data[ThemeColors.PrimaryColor]!.style);
  }

  static bool inDarkMode(BuildContext context) {
    return (AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark ||
        (AdaptiveTheme.of(context).mode == AdaptiveThemeMode.system &&
            SchedulerBinding.instance!.window.platformBrightness == Brightness.dark));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ThemeObject && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
