import './chat.dart';

class Handle {
  int? id;
  int? originalROWID;
  String address;
  String? country;
  String? color;
  String? defaultPhone;
  String? uncanonicalizedId;

  Handle({
    this.id,
    this.originalROWID,
    this.address = "",
    this.country,
    this.color,
    this.defaultPhone,
    this.uncanonicalizedId,
  });

  factory Handle.fromMap(Map<String, dynamic> json) => throw Exception("Unsupported Platform");

  Handle save() => throw Exception("Unsupported Platform");

  Handle updateColor(String? newColor) => throw Exception("Unsupported Platform");

  Handle updateDefaultPhone(String newPhone) => throw Exception("Unsupported Platform");

  static Handle? findOne({int? originalROWID, String? address}) => throw Exception("Unsupported Platform");

  static List<Handle> find() => throw Exception("Unsupported Platform");

  static List<Chat> getChats(Handle handle) => throw Exception("Unsupported Platform");

  static void flush() => throw Exception("Unsupported Platform");

  Map<String, dynamic> toMap() => throw Exception("Unsupported Platform");
}
