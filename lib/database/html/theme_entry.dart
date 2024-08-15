import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/database/html/objectbox.dart';
import 'package:bluebubbles/database/html/theme_object.dart';
import 'package:flutter/material.dart';

class ThemeEntry {
  int? id;
  int? themeId;
  String? name;
  Color? color;

  String? get dbColor => color?.value.toRadixString(16);

  set dbColor(String? s) => s == null ? color = null : color = HexColor(s);
  bool? isFont;
  int? fontSize;
  int? fontWeight;

  // ignore: deprecated_member_use_from_same_package
  final themeObject = ToOne<ThemeObject>();

  ThemeEntry({
    this.id,
    this.themeId,
    this.name,
    this.color,
    this.isFont,
    this.fontSize,
    this.fontWeight,
  });

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
}
