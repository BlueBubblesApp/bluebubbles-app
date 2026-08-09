import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

/// Migration that backfills [Chat.dbLatestMessage] and [Chat.dbOnlyLatestMessageDate]
/// for all existing chats by querying each chat's most recent non-deleted message.
class ChatLatestMessageMigration {
  static void migrate() {
    try {
      Logger.info("Starting chat latest message migration...", tag: "DB-Migration");
      _migrateChats();
      Logger.info("Chat latest message migration completed successfully", tag: "DB-Migration");
    } catch (e, stack) {
      Logger.error("Failed to complete chat latest message migration!", error: e, trace: stack, tag: "DB-Migration");
      rethrow;
    }
  }

  static void _migrateChats() {
    const int batchSize = 100;
    final chatBox = Database.chats;
    final messageBox = Database.messages;

    final totalChats = chatBox.count();
    Logger.info("Processing $totalChats chats for latest message backfill...", tag: "DB-Migration");

    int processed = 0;

    while (processed < totalChats) {
      final batchQuery = chatBox.query().build()
        ..limit = batchSize
        ..offset = processed;
      final batch = batchQuery.find();
      batchQuery.close();

      if (batch.isEmpty) break;

      final chatsToUpdate = <Chat>[];
      for (final chat in batch) {
        if (chat.id == null) continue;

        // Find the most recent non-deleted message for this chat.
        final msgQuery = (messageBox.query(Message_.dateDeleted.isNull())
              ..link(Message_.chat, Chat_.id.equals(chat.id!))
              ..order(Message_.dateCreated, flags: Order.descending))
            .build()
          ..limit = 1;
        final latest = msgQuery.findFirst();
        msgQuery.close();

        if (latest == null) continue;

        chat.dbLatestMessage.target = latest;
        chat.dbOnlyLatestMessageDate = latest.dateCreated;
        chatsToUpdate.add(chat);
      }

      if (chatsToUpdate.isNotEmpty) {
        chatBox.putMany(chatsToUpdate);
      }

      processed += batch.length;
      Logger.info("Backfilled $processed / $totalChats chats...", tag: "DB-Migration");
    }
  }
}
