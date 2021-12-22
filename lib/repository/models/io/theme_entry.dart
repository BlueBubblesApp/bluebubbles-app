import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/io/theme_object.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

@Entity()
class ThemeEntry {
  int? id;
  int? themeId;
  String? name;
  bool? isFont;
  int? fontSize;
  int? fontWeight;

  Color? color;
  String? get dbColor => color?.value.toRadixString(16);
  set dbColor(String? s) => s == null ? color = null : color = HexColor(s);

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

  ThemeEntry save(ThemeObject theme) {
    if (kIsWeb) return this;
    assert(theme.id != null);
    themeId = theme.id;
    store.runInTransaction(TxMode.write, () {
      ThemeEntry? existing = ThemeEntry.findOne(name!, themeId!);
      if (existing != null) {
        id = existing.id;
      } else {
        themeObject.target = theme;
      }
      id = themeEntryBox.put(this);
    });
    return this;
  }

  static ThemeEntry? findOne(String name, int themeId) {
    if (kIsWeb) return null;
    final query = themeEntryBox.query(ThemeEntry_.name.equals(name).and(ThemeEntry_.themeId.equals(themeId))).build();
    query.limit = 1;
    final result = query.findFirst();
    query.close();
    return result;
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
