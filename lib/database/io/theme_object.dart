import 'dart:core';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

@Deprecated('Use ThemeStruct instead')
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

  bool get isPreset =>
      name == "OLED Dark" ||
      name == "Bright White" ||
      name == "Nord Theme" ||
      name == "Music Theme (Light)" ||
      name == "Music Theme (Dark)";

  List<ThemeEntry> toEntries() => [
        ThemeEntry.fromStyle(ThemeColors.Headline1, data!.textTheme.displayLarge!),
        ThemeEntry.fromStyle(ThemeColors.Headline2, data!.textTheme.displayMedium!),
        ThemeEntry.fromStyle(ThemeColors.Bodytext1, data!.textTheme.bodyLarge!),
        ThemeEntry.fromStyle(ThemeColors.Bodytext2, data!.textTheme.bodyMedium!),
        ThemeEntry.fromStyle(ThemeColors.Subtitle1, data!.textTheme.titleMedium!),
        ThemeEntry.fromStyle(ThemeColors.Subtitle2, data!.textTheme.titleSmall!),
        ThemeEntry(name: ThemeColors.AccentColor, color: data!.colorScheme.secondary, isFont: false),
        ThemeEntry(name: ThemeColors.DividerColor, color: data!.dividerColor, isFont: false),
        ThemeEntry(name: ThemeColors.BackgroundColor, color: data!.colorScheme.background, isFont: false),
        ThemeEntry(name: ThemeColors.PrimaryColor, color: data!.primaryColor, isFont: false),
      ];

  static List<ThemeObject> getThemes() {
    final results = Database.themeObjects.getAll();
    final list = <ThemeObject>[];
    if (results.isNotEmpty) {
      final existing = list.map((e) => e.name);
      list.addAll(results.where((element) => !existing.contains(element.name)).map((e) => e..fetchData()));
    }
    return list;
  }

  List<ThemeEntry> fetchData() {
    if (isPreset && !name!.contains("Music")) {
      if (name == "OLED Dark") {
        data = ts.oledDarkTheme;
      } else if (name == "Bright White") {
        data = ts.whiteLightTheme;
      } else if (name == "Nord Theme") {
        data = ts.nordDarkTheme;
      }

      entries = toEntries();
      return entries;
    }
    if (kIsWeb) return entries;
    final themeEntries = List<ThemeEntry>.from(this.themeEntries);
    if (name == "Music Theme (Light)" && themeEntries.isEmpty) {
      data = ts.whiteLightTheme;
      entries = toEntries();
    } else if (name == "Music Theme (Dark)" && themeEntries.isEmpty) {
      data = ts.oledDarkTheme;
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
          displayLarge: data[ThemeColors.Headline1]!.style,
          displayMedium: data[ThemeColors.Headline2]!.style,
          bodyLarge: data[ThemeColors.Bodytext1]!.style,
          bodyMedium: data[ThemeColors.Bodytext2]!.style,
          titleMedium: data[ThemeColors.Subtitle1]!.style,
          titleSmall: data[ThemeColors.Subtitle2]!.style,
        ),
        colorScheme: ColorScheme.fromSwatch(
          accentColor: data[ThemeColors.AccentColor]!.style,
          backgroundColor: data[ThemeColors.BackgroundColor]!.style,
        ),
        dividerColor: data[ThemeColors.DividerColor]!.style,
        primaryColor: data[ThemeColors.PrimaryColor]!.style);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ThemeObject && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
