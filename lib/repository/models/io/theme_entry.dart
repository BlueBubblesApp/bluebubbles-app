import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:bluebubbles/repository/models/io/join_tables.dart';
import 'package:bluebubbles/repository/models/io/theme_object.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@Entity()
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
    if (kIsWeb) return this;
    assert(theme.id != null);
    this.themeId = theme.id;
    ThemeEntry? existing = ThemeEntry.findOne(this.name!, this.themeId!);
    if (existing != null) {
      this.id = existing.id;
    }
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    themeEntryBox.put(this);
    if (this.id != null && theme.id != null && existing == null)
      // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
      tvJoinBox.put(ThemeValueJoin(themeValueId: this.id!, themeId: theme.id!));

    return this;
  }

  static ThemeEntry? findOne(String name, int themeId) {
    if (kIsWeb) return null;
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    final query = themeEntryBox.query(ThemeEntry_.name.equals(name).and(ThemeEntry_.themeId.equals(themeId))).build();
    query..limit = 1;
    final result = query.findFirst();
    query.close();
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    return result;
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
