import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/repository/models/html/theme_object.dart';
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

  ThemeEntry({
    this.id,
    this.themeId,
    this.name,
    this.color,
    this.isFont,
    this.fontSize,
  });

  factory ThemeEntry.fromMap(Map<String, dynamic> json) {
    return ThemeEntry(
      id: json["ROWID"],
      themeId: json["themeId"],
      name: json["name"],
      color: HexColor(json["color"]),
      isFont: json["isFont"] == 1,
      fontSize: json["fontSize"],
    );
  }

  factory ThemeEntry.fromStyle(String title, TextStyle style) {
    return ThemeEntry(
      color: style.color,
      name: title,
      isFont: true,
      fontSize: style.fontSize != null ? style.fontSize!.toInt() : 14,
    );
  }

  dynamic get style => isFont!
      ? TextStyle(
          color: this.color,
          fontWeight: FontWeight.normal,
          fontSize: fontSize?.toDouble() ?? null,
        )
      : color;

  ThemeEntry save(ThemeObject theme) {
    return this;
  }

  static ThemeEntry? findOne(String name, int themeId) {
    return null;
  }

  Map<String, dynamic> toMap() => {
        "ROWID": this.id,
        "name": this.name,
        "themeId": this.themeId,
        "color": this.color!.value.toRadixString(16),
        "isFont": this.isFont! ? 1 : 0,
        "fontSize": this.fontSize,
      };
}
