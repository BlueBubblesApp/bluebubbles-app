import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

class CustomGroupActions {
  static Future<int> create(dynamic data) async {
    final name = data['name'] as String;
    // Dedupe so a repeated guid in the input can't create duplicate rows in
    // the group<->chat relation.
    final chatGuids = (data['chatGuids'] as List).cast<String>().toSet();
    return Database.runInTransaction(TxMode.write, () {
      final group = CustomGroup(name: name);
      final matchedChats = chatGuids
          .map((guid) => Database.chats.query(Chat_.guid.equals(guid)).build().findFirst())
          .whereType<Chat>()
          .toList();
      group.chats.addAll(matchedChats);
      try {
        return Database.customGroups.put(group);
      } on UniqueViolationException catch (_) {
        Logger.warn('Duplicate custom group name — skipping', tag: 'CustomGroupActions');
        rethrow;
      }
    });
  }

  static Future<int> rename(dynamic data) async {
    final id = data['id'] as int;
    final name = data['name'] as String;
    return Database.runInTransaction(TxMode.write, () {
      final group = Database.customGroups.get(id)!;
      group.name = name;
      try {
        return Database.customGroups.put(group);
      } on UniqueViolationException catch (_) {
        Logger.warn('Duplicate custom group name — skipping', tag: 'CustomGroupActions');
        rethrow;
      }
    });
  }

  static Future<int> updateChats(dynamic data) async {
    final id = data['id'] as int;
    // Dedupe so a repeated guid in the input can't create duplicate rows in
    // the group<->chat relation.
    final chatGuids = (data['chatGuids'] as List).cast<String>().toSet();
    return Database.runInTransaction(TxMode.write, () {
      final group = Database.customGroups.get(id)!;
      final matchedChats = chatGuids
          .map((guid) => Database.chats.query(Chat_.guid.equals(guid)).build().findFirst())
          .whereType<Chat>()
          .toList();
      group.chats.clear();
      group.chats.addAll(matchedChats);
      group.chats.applyToDb();
      return group.id!;
    });
  }

  static Future<int> setShowUnreadBadge(dynamic data) async {
    final id = data['id'] as int;
    final value = data['value'] as bool;
    return Database.runInTransaction(TxMode.write, () {
      final group = Database.customGroups.get(id)!;
      group.showUnreadBadge = value;
      return Database.customGroups.put(group);
    });
  }

  static Future<List<int>> getAllIds(dynamic data) async {
    return Database.runInTransaction(TxMode.read, () {
      final groups = Database.customGroups.getAll();
      groups.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return groups.map((g) => g.id!).toList();
    });
  }

  static Future<void> reorder(dynamic data) async {
    final ids = (data['ids'] as List).cast<int>();
    Database.runInTransaction(TxMode.write, () {
      for (var i = 0; i < ids.length; i++) {
        final group = Database.customGroups.get(ids[i]);
        if (group == null) continue;
        group.sortOrder = i;
        Database.customGroups.put(group);
      }
    });
  }

  static Future<void> delete(dynamic data) async {
    final id = data['id'] as int;
    Database.runInTransaction(TxMode.write, () => Database.customGroups.remove(id));
  }
}
