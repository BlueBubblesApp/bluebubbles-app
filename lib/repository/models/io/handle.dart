import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/objectbox.g.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Condition;
// (needed when generating objectbox model code)
// ignore: unnecessary_import
import 'package:objectbox/objectbox.dart';

@Entity()
class Handle {
  int? id;
  int? originalROWID;
  @Unique()
  String address;
  String? country;
  String? defaultPhone;
  String? uncanonicalizedId;

  final RxnString _color = RxnString();
  String? get color => _color.value;
  set color(String? val) => _color.value = val;

  Handle({
    this.id,
    this.originalROWID,
    this.address = "",
    this.country,
    String? handleColor,
    this.defaultPhone,
    this.uncanonicalizedId,
  }) {
    color = handleColor;
  }

  factory Handle.fromMap(Map<String, dynamic> json) {
    var data = Handle(
      id: json.containsKey("ROWID") ? json["ROWID"] : null,
      originalROWID: json.containsKey("originalROWID") ? json["originalROWID"] : null,
      address: json["address"],
      country: json.containsKey("country") ? json["country"] : null,
      handleColor: json.containsKey("color") ? json["color"] : null,
      defaultPhone: json['defaultPhone'],
      uncanonicalizedId: json.containsKey("uncanonicalizedId") ? json["uncanonicalizedId"] : null,
    );

    // Adds fallback getter for the ID
    data.id ??= json.containsKey("id") ? json["id"] : null;

    return data;
  }

  /// Save a single handle - prefer [bulkSave] for multiple handles rather
  /// than iterating through them
  Handle save({bool updateColor = false}) {
    if (kIsWeb) return this;
    store.runInTransaction(TxMode.write, () {
      Handle? existing = Handle.findOne(address: address);
      if (existing != null) {
        id = existing.id;
      }
      if (!updateColor) {
        color = existing?.color ?? color;
      }
      try {
        id = handleBox.put(this);
      } on UniqueViolationException catch (_) {}
    });
    return this;
  }

  /// Save a list of handles
  static List<Handle> bulkSave(List<Handle> handles) {
    store.runInTransaction(TxMode.write, () {
      /// Find a list of existing handles
      List<Handle> existingHandles = Handle.find(cond: Handle_.address.oneOf(handles.map((e) => e.address).toList()));

      /// Match existing to the handles to save, where possible
      for (Handle h in handles) {
        final existing = existingHandles.firstWhereOrNull((e) => e.address == h.address);
        if (existing != null) {
          h.id = existing.id;
        }
      }
      try {
        /// Save the handles and update their IDs
        final ids = handleBox.putMany(handles);
        for (int i = 0; i < handles.length; i++) {
          handles[i].id = ids[i];
        }
      } on UniqueViolationException catch (_) {}
    });
    return handles;
  }

  Handle updateColor(String? newColor) {
    color = newColor;
    save();
    return this;
  }

  Handle updateDefaultPhone(String newPhone) {
    defaultPhone = newPhone;
    save();
    return this;
  }

  static Handle? findOne({int? id, int? originalROWID, String? address}) {
    if (kIsWeb || id == 0) return null;
    if (id != null) {
      final handle = handleBox.get(id) ?? Handle.findOne(originalROWID: id);
      return handle;
    } else if (originalROWID != null) {
      final query = handleBox.query(Handle_.originalROWID.equals(originalROWID)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    } else {
      final query = handleBox.query(Handle_.address.equals(address!)).build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();
      return result;
    }
  }

  /// Find a list of handles by the specified condition, or return all handles
  /// when no condition is specified
  static List<Handle> find({Condition<Handle>? cond}) {
    final query = handleBox.query(cond).build();
    return query.find();
  }

  static void flush() {
    if (kIsWeb) return;
    handleBox.removeAll();
  }

  Map<String, dynamic> toMap() => {
        "ROWID": id,
        "originalROWID": originalROWID,
        "address": address,
        "country": country,
        "color": color,
        "defaultPhone": defaultPhone,
        "uncanonicalizedId": uncanonicalizedId,
      };
}
