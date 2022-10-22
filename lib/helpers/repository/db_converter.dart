import 'package:get/get.dart';

/// Helper class to convert db values given a type and a value
class DBConverter {
  static const Map<Type, String> types = {
    bool: "bool",
    double: "double",
    int: "int",
    String: "string",
    RxBool: "bool",
    RxDouble: "double",
    RxInt: "int",
    RxString: "string",
  };

  static Type? getType(String type) {
    return types.containsValue(type) ? types.keys.firstWhere((key) => types[key] == type) : null;
  }

  static String? getStringType(Type? type) {
    return types.containsKey(type) ? types[type!] : null;
  }

  static String? getString(dynamic value) {
    if (value.runtimeType == bool) {
      return value ? "1" : "0";
    } else if (value.runtimeType == double) {
      return value.toString();
    } else if (value.runtimeType == int) {
      return value.toString();
    } else if (value.runtimeType == String) {
      return value;
    } else {
      return null;
    }
  }

  static dynamic getValue(String value, String type) {
    if (type == types[bool]) {
      return value == "1";
    } else if (type == types[double]) {
      return double.tryParse(value);
    } else if (type == types[int]) {
      return int.tryParse(value);
    } else if (type == types[String]) {
      return value;
    } else {
      return null;
    }
  }
}
