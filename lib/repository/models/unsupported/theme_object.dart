import 'dart:core';
import 'package:flutter/material.dart';

import '../models.dart';

class ThemeObject {
  int? id;
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

  factory ThemeObject.fromData(ThemeData data, String name, {bool gradientBg = false}) => throw Exception("Unsupported Platform");

  factory ThemeObject.fromMap(Map<String, dynamic> json) => throw Exception("Unsupported Platform");

  bool get isPreset => throw Exception("Unsupported Platform");

  List<ThemeEntry> toEntries() => throw Exception("Unsupported Platform");

  ThemeObject save({bool updateIfNotAbsent = true}) => throw Exception("Unsupported Platform");

  void delete() => throw Exception("Unsupported Platform");

  static ThemeObject getLightTheme() => throw Exception("Unsupported Platform");

  static ThemeObject getDarkTheme() => throw Exception("Unsupported Platform");

  static void setSelectedTheme({int? light, int? dark}) => throw Exception("Unsupported Platform");

  static ThemeObject? findOne(String name) => throw Exception("Unsupported Platform");

  static List<ThemeObject> getThemes() => throw Exception("Unsupported Platform");

  List<ThemeEntry> fetchData() => throw Exception("Unsupported Platform");

  Map<String, dynamic> toMap() => throw Exception("Unsupported Platform");

  ThemeData get themeData => throw Exception("Unsupported Platform");

  static bool inDarkMode(BuildContext context) => throw Exception("Unsupported Platform");

  @override
  bool operator ==(Object other) => throw Exception("Unsupported Platform");

  @override
  int get hashCode => throw Exception("Unsupported Platform");
}
