import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

/// Migration for converting Message.handle from embedded object to ToOne&lt;Handle&gt; relationship
/// This migration populates the handleRelation field for all existing messages
class MessageHandleRelationshipMigration {
  /// Execute the migration to populate handleRelation for all messages
  static Future<void> migrate() async {
    try {
      Logger.info("Starting Message-Handle relationship migration (Phase 2)...", tag: "DB-Migration");

      await _migrateMessageHandleRelationships();

      Logger.info("Message-Handle relationship migration (Phase 2) completed successfully", tag: "DB-Migration");
    } catch (e, stack) {
      Logger.error("Failed to complete Message-Handle relationship migration!",
          error: e, trace: stack, tag: "DB-Migration");
      rethrow;
    }
  }

  /// Migrate all messages to use ToOne&lt;Handle&gt; relationship instead of embedded Handle object
  static Future<void> _migrateMessageHandleRelationships() async {
    try {
      Logger.info("Fetching all handles for migration lookup...", tag: "DB-Migration");

      final allHandles = Database.handles.getAll();
      final handleIdMap = <int, Handle>{};
      for (final handle in allHandles) {
        if (handle.id != null && handle.originalROWID != null) {
          // I thought that using handleId would work, but it seems originalROWID is the correct field to use.
          handleIdMap[handle.originalROWID!] = handle;
        }
      }

      Logger.info("Found ${allHandles.length} handles. Processing messages in batches...", tag: "DB-Migration");

      // Process messages in batches to avoid memory issues with large databases
      const int batchSize = 1000;
      final int totalMessages = Database.messages.count();
      int processed = 0;
      int migrated = 0;
      int skipped = 0;
      int notFound = 0;

      while (processed < totalMessages) {
        final query = Database.messages.query().build();
        query
          ..offset = processed
          ..limit = batchSize;
        final batch = query.find();
        query.close();

        if (batch.isEmpty) break;

        final messagesToUpdate = <Message>[];

        for (final message in batch) {
          // Skip messages that are from the current user (no handle needed)
          if (message.isFromMe == true || message.handleId == null || message.handleId == 0) {
            skipped++;
            continue;
          }

          // Leaving this commented out as we want to re-set relationships in case they were not set correctly before
          // Skip if relationship is already set (in case migration is run multiple times)
          // if (message.handleRelation.hasValue) {
          //   skipped++;
          //   continue;
          // }

          // Find the corresponding handle
          final handle = handleIdMap[message.handleId];

          if (handle != null && handle.id != null) {
            message.handleRelation.target = handle;
            messagesToUpdate.add(message);
            migrated++;
          } else {
            Logger.warn(
                "Could not find handle with originalROWID ${message.originalROWID} for message ${message.guid}. "
                "Handle ID in DB: ${handle?.id}",
                tag: "DB-Migration");
            notFound++;
            skipped++;
          }
        }

        // Save the batch with updated relationships
        if (messagesToUpdate.isNotEmpty) {
          Database.messages.putMany(messagesToUpdate);
        }

        processed += batch.length;

        // Per batch
        await StartupTasks.setSplashProgress(processed / totalMessages);

        // Log progress every 5000 messages or at the end
        if (processed % 5000 == 0 || processed >= totalMessages) {
          Logger.info(
              "Migration progress: $processed/$totalMessages messages processed, "
              "$migrated migrated, $skipped skipped, $notFound handles not found",
              tag: "DB-Migration");
        }
      }

      Logger.info(
          "Message-Handle relationship migration complete: "
          "$migrated messages migrated, $skipped skipped (${skipped - notFound} already had relationships or were from me, $notFound handles not found)",
          tag: "DB-Migration");
    } catch (e, stack) {
      Logger.error("Failed to migrate message-handle relationships!", error: e, trace: stack, tag: "DB-Migration");
      rethrow;
    }
  }

  /// Verify that the migration completed successfully
  /// This should be run before Phase 4 (marking handle as transient)
  static void verify() {
    try {
      Logger.info("Verifying Message-Handle relationships...", tag: "DB-Migration");

      final totalMessages = Database.messages.count();
      final messagesWithRelations = Database.messages.query(Message_.handleRelation.notNull()).build().count();

      final messagesFromMe = Database.messages.query(Message_.isFromMe.equals(true)).build().count();

      final expectedWithRelations = totalMessages - messagesFromMe;

      Logger.info(
          "Total messages: $totalMessages, "
          "From me: $messagesFromMe, "
          "With handle relations: $messagesWithRelations, "
          "Expected: $expectedWithRelations",
          tag: "DB-Migration");

      // Allow for some tolerance (95%) since some messages might legitimately not have handles
      final double completionRate = expectedWithRelations > 0 ? messagesWithRelations / expectedWithRelations : 1.0;

      if (completionRate < 0.95) {
        Logger.error(
            "Handle relationship verification failed! "
            "Only $messagesWithRelations/$expectedWithRelations messages have handle relationships (${(completionRate * 100).toStringAsFixed(1)}%). "
            "Migration may be incomplete.",
            tag: "DB-Migration");
        throw Exception(
            "Handle relationship verification failed - completion rate: ${(completionRate * 100).toStringAsFixed(1)}%");
      }

      Logger.info(
          "Handle relationship verification passed! Completion rate: ${(completionRate * 100).toStringAsFixed(1)}%",
          tag: "DB-Migration");
    } catch (e, stack) {
      Logger.error("Failed to verify handle relationships!", error: e, trace: stack, tag: "DB-Migration");
      rethrow;
    }
  }
}
