import 'dart:convert';
import 'dart:core';

import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

@Entity()
class ThemeStruct {
  int? id;
  @Unique()
  String name;
  bool gradientBg = false;
  ThemeData data;

  String get dbThemeData {
    final map = toMap()['data'];
    return jsonEncode(map);
  }

  set dbThemeData(String str) {
    final map = jsonDecode(str);
    data = ThemeStruct.fromMap({
      "name": "temp",
      "data": map
    }).data;
  }

  ThemeStruct({
    this.id,
    required this.name,
    this.gradientBg = false,
    ThemeData? themeData,
  }) : data = themeData ?? whiteLightTheme;

  bool get isPreset =>
      name == "OLED Dark" ||
          name == "Bright White" ||
          name == "Nord Theme" ||
          name == "Music Theme (Light)" ||
          name == "Music Theme (Dark)";

  ThemeStruct save({bool updateIfNotAbsent = true}) {
    store.runInTransaction(TxMode.write, () {
      ThemeStruct? existing = ThemeStruct.findOne(name);
      if (existing != null) {
        id = existing.id;
      }
      try {
        if (id != null && existing != null && updateIfNotAbsent) {
          id = themeBox.put(this);
        } else if (id == null || existing == null) {
          id = themeBox.put(this);
        }
      } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  void delete() {
    if (kIsWeb || isPreset || id == null) return;
    store.runInTransaction(TxMode.write, () {
      themeBox.remove(id!);
    });
  }

  static ThemeStruct getLightTheme() {
    final name = prefs.getString("selected-light");
    final query = themeBox.query(ThemeStruct_.name.equals(name!)).build();
    query.limit = 1;
    final result = query.findFirst();
    if (result == null) {
      return Themes.defaultThemes[1];
    }
    return result;
  }

  static ThemeStruct getDarkTheme() {
    final name = prefs.getString("selected-dark");
    final query = themeBox.query(ThemeStruct_.name.equals(name!)).build();
    query.limit = 1;
    final result = query.findFirst();
    if (result == null) {
      return Themes.defaultThemes[0];
    }
    return result;
  }

  static ThemeStruct? findOne(String name) {
    if (kIsWeb) return null;
    return store.runInTransaction(TxMode.read, () {
      final query = themeBox.query(ThemeStruct_.name.equals(name)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    });
  }

  static List<ThemeStruct> getThemes() {
    if (kIsWeb) return Themes.defaultThemes;
    return themeBox.getAll();
  }

  Map<String, dynamic> toMap() => {
    "ROWID": id,
    "name": name,
    "gradientBg": gradientBg ? 1 : 0,
    "data": {
      "textTheme": {
        "headlineMedium": {
          "color": data.textTheme.headlineMedium!.color!.value,
          "fontWeight": data.textTheme.headlineMedium!.fontWeight!.index,
          "fontSize": data.textTheme.headlineMedium!.fontSize,
        },
        "titleMedium": {
          "color": data.textTheme.titleMedium!.color!.value,
          "fontWeight": data.textTheme.titleMedium!.fontWeight!.index,
          "fontSize": data.textTheme.titleMedium!.fontSize,
        },
        "bodyMedium": {
          "color": data.textTheme.bodyMedium!.color!.value,
          "fontWeight": data.textTheme.bodyMedium!.fontWeight!.index,
          "fontSize": data.textTheme.bodyMedium!.fontSize,
        },
        "bodySmall": {
          "color": data.textTheme.bodySmall!.color!.value,
          "fontWeight": data.textTheme.bodySmall!.fontWeight!.index,
          "fontSize": data.textTheme.bodySmall!.fontSize,
        },
        "labelLarge": {
          "color": data.textTheme.labelLarge!.color!.value,
          "fontWeight": data.textTheme.labelLarge!.fontWeight!.index,
          "fontSize": data.textTheme.labelLarge!.fontSize,
        },
        "labelMedium": {
          "color": data.textTheme.labelMedium!.color!.value,
          "fontWeight": data.textTheme.labelMedium!.fontWeight!.index,
          "fontSize": data.textTheme.labelMedium!.fontSize,
        }
      },
      "colorScheme": {
        "primary": data.colorScheme.primary.value,
        "onPrimary": data.colorScheme.onPrimary.value,
        "primaryContainer": data.colorScheme.primaryContainer.value,
        "onPrimaryContainer": data.colorScheme.onPrimaryContainer.value,
        "secondary": data.colorScheme.secondary.value,
        "onSecondary": data.colorScheme.onSecondary.value,
        "secondaryContainer": data.colorScheme.secondaryContainer.value,
        "onSecondaryContainer": data.colorScheme.onSecondaryContainer.value,
        "tertiary": data.colorScheme.tertiary.value,
        "onTertiary": data.colorScheme.onTertiary.value,
        "tertiaryContainer": data.colorScheme.tertiaryContainer.value,
        "onTertiaryContainer": data.colorScheme.onTertiaryContainer.value,
        "error": data.colorScheme.error.value,
        "onError": data.colorScheme.onError.value,
        "errorContainer": data.colorScheme.errorContainer.value,
        "onErrorContainer": data.colorScheme.onErrorContainer.value,
        "background": data.colorScheme.background.value,
        "onBackground": data.colorScheme.onBackground.value,
        "surface": data.colorScheme.surface.value,
        "onSurface": data.colorScheme.onSurface.value,
        "surfaceVariant": data.colorScheme.surfaceVariant.value,
        "onSurfaceVariant": data.colorScheme.onSurfaceVariant.value,
        "outline": data.colorScheme.outline.value,
        "shadow": data.colorScheme.shadow.value,
        "inverseSurface": data.colorScheme.inverseSurface.value,
        "onInverseSurface": data.colorScheme.onInverseSurface.value,
        "inversePrimary": data.colorScheme.inversePrimary.value,
        "brightness": data.colorScheme.brightness.index,
      },
      "useMaterial3": data.useMaterial3,
      "typography": data.useMaterial3 ? 1 : 0,
      "splashFactory": data.useMaterial3 ? 1 : 0,
    },
  };

  factory ThemeStruct.fromMap(Map<String, dynamic> json) {
    final map = json["data"];
    return ThemeStruct(
        id: json["ROWID"],
        name: json["name"],
        gradientBg: json["gradientBg"] == 1,
        themeData: ThemeData(
          textTheme: TextTheme(
            headlineMedium: TextStyle(
              color: Color(map["textTheme"]["headlineMedium"]["color"]),
              fontWeight: FontWeight.values[map["textTheme"]["headlineMedium"]["fontWeight"]],
              fontSize: map["textTheme"]["headlineMedium"]["fontSize"],
            ),
            titleMedium: TextStyle(
              color: Color(map["textTheme"]["titleMedium"]["color"]),
              fontWeight: FontWeight.values[map["textTheme"]["titleMedium"]["fontWeight"]],
              fontSize: map["textTheme"]["titleMedium"]["fontSize"],
            ),
            bodyMedium: TextStyle(
              color: Color(map["textTheme"]["bodyMedium"]["color"]),
              fontWeight: FontWeight.values[map["textTheme"]["bodyMedium"]["fontWeight"]],
              fontSize: map["textTheme"]["bodyMedium"]["fontSize"],
            ),
            bodySmall: TextStyle(
              color: Color(map["textTheme"]["bodySmall"]["color"]),
              fontWeight: FontWeight.values[map["textTheme"]["bodySmall"]["fontWeight"]],
              fontSize: map["textTheme"]["bodySmall"]["fontSize"],
            ),
            labelLarge: TextStyle(
              color: Color(map["textTheme"]["labelLarge"]["color"]),
              fontWeight: FontWeight.values[map["textTheme"]["labelLarge"]["fontWeight"]],
              fontSize: map["textTheme"]["labelLarge"]["fontSize"],
            ),
            labelMedium: TextStyle(
              color: Color(map["textTheme"]["labelMedium"]["color"]),
              fontWeight: FontWeight.values[map["textTheme"]["labelMedium"]["fontWeight"]],
              fontSize: map["textTheme"]["labelMedium"]["fontSize"],
            ),
          ),
          colorScheme: ColorScheme(
            primary: Color(map["colorScheme"]["primary"]),
            onPrimary: Color(map["colorScheme"]["onPrimary"]),
            primaryContainer: Color(map["colorScheme"]["primaryContainer"]),
            onPrimaryContainer: Color(map["colorScheme"]["onPrimaryContainer"]),
            secondary: Color(map["colorScheme"]["secondary"]),
            onSecondary: Color(map["colorScheme"]["onSecondary"]),
            secondaryContainer: Color(map["colorScheme"]["secondaryContainer"]),
            onSecondaryContainer: Color(map["colorScheme"]["onSecondaryContainer"]),
            tertiary: Color(map["colorScheme"]["tertiary"]),
            onTertiary: Color(map["colorScheme"]["onTertiary"]),
            tertiaryContainer: Color(map["colorScheme"]["tertiaryContainer"]),
            onTertiaryContainer: Color(map["colorScheme"]["onTertiaryContainer"]),
            error: Color(map["colorScheme"]["error"]),
            onError: Color(map["colorScheme"]["onError"]),
            errorContainer: Color(map["colorScheme"]["errorContainer"]),
            onErrorContainer: Color(map["colorScheme"]["onErrorContainer"]),
            background: Color(map["colorScheme"]["background"]),
            onBackground: Color(map["colorScheme"]["onBackground"]),
            surface: Color(map["colorScheme"]["surface"]),
            onSurface: Color(map["colorScheme"]["onSurface"]),
            surfaceVariant: Color(map["colorScheme"]["surfaceVariant"]),
            onSurfaceVariant: Color(map["colorScheme"]["onSurfaceVariant"]),
            outline: Color(map["colorScheme"]["outline"]),
            shadow: Color(map["colorScheme"]["shadow"]),
            inverseSurface: Color(map["colorScheme"]["inverseSurface"]),
            onInverseSurface: Color(map["colorScheme"]["onInverseSurface"]),
            inversePrimary: Color(map["colorScheme"]["inversePrimary"]),
            brightness: Brightness.values[map["colorScheme"]["brightness"]],
          ),
          useMaterial3: map["useMaterial3"],
          typography: map["typography"] == 1 ? Typography.material2021() : Typography.material2018(),
          splashFactory: map["splashFactory"] == 1 ? InkSparkle.splashFactory : InkRipple.splashFactory,
        )
    );
  }

  Map<String, Color> get colors => {
    "primary": data.colorScheme.primary,
    "onPrimary": data.colorScheme.onPrimary,
    "primaryContainer": data.colorScheme.primaryContainer,
    "onPrimaryContainer": data.colorScheme.onPrimaryContainer,
    "secondary": data.colorScheme.secondary,
    "onSecondary": data.colorScheme.onSecondary,
    "secondaryContainer": data.colorScheme.secondaryContainer,
    "onSecondaryContainer": data.colorScheme.onSecondaryContainer,
    "tertiary": data.colorScheme.tertiary,
    "onTertiary": data.colorScheme.onTertiary,
    "tertiaryContainer": data.colorScheme.tertiaryContainer,
    "onTertiaryContainer": data.colorScheme.onTertiaryContainer,
    "error": data.colorScheme.error,
    "onError": data.colorScheme.onError,
    "errorContainer": data.colorScheme.errorContainer,
    "onErrorContainer": data.colorScheme.onErrorContainer,
    "background": data.colorScheme.background,
    "onBackground": data.colorScheme.onBackground,
    "surface": data.colorScheme.surface,
    "onSurface": data.colorScheme.onSurface,
    "surfaceVariant": data.colorScheme.surfaceVariant,
    "onSurfaceVariant": data.colorScheme.onSurfaceVariant,
    "inverseSurface": data.colorScheme.inverseSurface,
    "onInverseSurface": data.colorScheme.onInverseSurface,
    // the following get their own customization card, rather than
    // being paired like the above
    "outline": data.colorScheme.outline,
    "shadow": data.colorScheme.shadow,
    "inversePrimary": data.colorScheme.inversePrimary,
  };

  @override
  bool operator ==(Object other) =>
      other is ThemeStruct && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
