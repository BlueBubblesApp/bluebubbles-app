import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/models/models.dart' show HandleLookupKey;

class HandleActions {
  static Future<int> saveHandleAsync(dynamic data) async {
    final handleData = data['handleData'] as Map<String, dynamic>;
    final updateColor = data['updateColor'] as bool;
    final matchOnOriginalROWID = data['matchOnOriginalROWID'] as bool;

    final handle = Handle.fromMap(handleData);

    // Format the address before entering the transaction (async not allowed inside)
    await handle.updateFormattedAddress();

    return Database.runInTransaction(TxMode.write, () {
      Handle? existing;
      if (matchOnOriginalROWID) {
        existing = Handle.findOne(originalROWID: handle.originalROWID);
      } else {
        existing = Handle.findOne(addressAndService: HandleLookupKey(handle.address, handle.service));
      }

      if (existing != null) {
        handle.id = existing.id;
        handle.originalROWID ??= existing.originalROWID;
      }
      // Contact matching is now handled automatically by ContactServiceV2
      if (!updateColor) {
        handle.color = existing?.color ?? handle.color;
      }

      try {
        handle.id = Database.handles.put(handle);
      } on UniqueViolationException catch (_) {}

      // Return just the ID for efficient transfer across isolates
      return handle.id!;
    });
  }

  static Future<List<int>> bulkSaveHandlesAsync(dynamic data) async {
    final handlesData = (data['handlesData'] as List).cast<Map<String, dynamic>>();
    final matchOnOriginalROWID = data['matchOnOriginalROWID'] as bool;

    final handles = handlesData.map((e) => Handle.fromMap(e)).toList();

    // Format addresses before entering the transaction (async not allowed inside)
    for (Handle h in handles) {
      await h.updateFormattedAddress();
    }

    return Database.runInTransaction(TxMode.write, () {
      /// Match existing to the handles to save, where possible
      for (Handle h in handles) {
        Handle? existing;
        if (matchOnOriginalROWID) {
          existing = Handle.findOne(originalROWID: h.originalROWID);
        } else {
          existing = Handle.findOne(addressAndService: HandleLookupKey(h.address, h.service));
        }

        if (existing != null) {
          h.id = existing.id;
          h.originalROWID ??= existing.originalROWID;
        }
        // Contact matching is now handled automatically by ContactServiceV2
      }

      List<int> insertedIds = Database.handles.putMany(handles);
      for (int i = 0; i < insertedIds.length; i++) {
        handles[i].id = insertedIds[i];
      }

      // Return just the IDs for efficient transfer across isolates
      return handles.map((e) => e.id!).toList();
    });
  }

  static Future<int?> findOneHandleAsync(dynamic data) async {
    final id = data['id'] as int?;
    final originalROWID = data['originalROWID'] as int?;
    final address = data['address'] as String?;
    final service = data['service'] as String?;

    return Database.runInTransaction(TxMode.read, () {
      final handleBox = Database.handles;

      Handle? result;

      if (id != null && id != 0) {
        result = handleBox.get(id);
        if (result == null) {
          // Try finding by originalROWID if direct ID lookup fails
          final query = handleBox.query(Handle_.originalROWID.equals(id)).build();
          query.limit = 1;
          result = query.findFirst();
          query.close();
        }
      } else if (originalROWID != null) {
        final query = handleBox.query(Handle_.originalROWID.equals(originalROWID)).build();
        query.limit = 1;
        result = query.findFirst();
        query.close();
      } else if (address != null && service != null) {
        final query = handleBox.query(Handle_.address.equals(address) & Handle_.service.equals(service)).build();
        query.limit = 1;
        result = query.findFirst();
        query.close();
      }

      // Return just the ID for efficient transfer across isolates
      return result?.id;
    });
  }

  static Future<List<int>> findHandlesAsync(dynamic data) async {
    return Database.runInTransaction(TxMode.read, () {
      final handleBox = Database.handles;

      final query = handleBox.query().build();
      final results = query.find();
      query.close();

      // Return just the IDs for efficient transfer across isolates
      return results.map((e) => e.id!).toList();
    });
  }
}
