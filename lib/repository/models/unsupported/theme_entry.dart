import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:flutter/material.dart';
import '../models.dart';

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

  factory ThemeEntry.fromMap(Map<String, dynamic> json) => throw Exception("Unsupported Platform");

  factory ThemeEntry.fromStyle(String title, TextStyle style) => throw Exception("Unsupported Platform");

  dynamic get style => throw Exception("Unsupported Platform");

  ThemeEntry save(ThemeObject theme) => throw Exception("Unsupported Platform");

  static ThemeEntry? findOne(String name, int themeId) => throw Exception("Unsupported Platform");

  Map<String, dynamic> toMap() => throw Exception("Unsupported Platform");
}
