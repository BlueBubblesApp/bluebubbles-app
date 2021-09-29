import 'package:bluebubbles/repository/helpers/db_converter.dart';

class ConfigEntry<T> {
  int? id;
  String? name;
  T? value;
  Type? type;

  ConfigEntry({
    this.id,
    this.name,
    this.value,
    this.type,
  });

  static ConfigEntry fromMap(Map<String, dynamic> json) {
    String _type = json["type"] ?? "";
    Type t = DBConverter.getType(_type) ?? String;
    if (t == bool) {
      return ConfigEntry<bool>(
        id: json["ROWID"],
        name: json["name"],
        value: DBConverter.getValue(json["value"], _type),
        type: t,
      );
    } else if (t == double) {
      return ConfigEntry<double>(
        id: json["ROWID"],
        name: json["name"],
        value: DBConverter.getValue(json["value"], _type),
        type: t,
      );
    } else if (t == int) {
      return ConfigEntry<int>(
        id: json["ROWID"],
        name: json["name"],
        value: DBConverter.getValue(json["value"], _type),
        type: t,
      );
    } else {
      return ConfigEntry<String>(
        id: json["ROWID"],
        name: json["name"],
        value: DBConverter.getValue(json["value"], _type),
        type: t,
      );
    }
  }
}
