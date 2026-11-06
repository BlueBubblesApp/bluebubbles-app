import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/descriptors/attachment_query_descriptor.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:universal_io/io.dart';

/// A file or directory to move once the transaction that renamed its attachment has committed
typedef RekeyedFileMove = ({String from, String to});

class AttachmentActions {
  /// Renames rows still saved under an attachment's [Attachment.originalGuid] to the guid the server now serves, so
  /// the guid lookups that follow find them. Call before matching incoming attachments by guid. A row saved under
  /// both guids is the same attachment twice, so the old one is removed.
  ///
  /// Returns the files to move to the new guids: pass them to [moveRekeyedFiles] after the transaction commits, so a
  /// rollback can't leave a file where its row doesn't point.
  static List<RekeyedFileMove> adoptRekeyedGuids(Iterable<Attachment> incoming) {
    final renamed = {
      for (final a in incoming)
        if (a.guid != null && a.originalGuid != null && a.originalGuid != a.guid) a.originalGuid!: a.guid!,
    };
    if (renamed.isEmpty) return const [];

    final query = Database.attachments.query(Attachment_.guid.oneOf(renamed.keys.toList())).build();
    final stale = query.find();
    query.close();
    final moves = <RekeyedFileMove>[];
    for (final row in stale) {
      final newGuid = renamed[row.guid]!;
      final current = findOne(newGuid);
      if (current != null) {
        // Keep the old row's file and message when the new row has none
        if (!File(current.path).existsSync()) moves.add((from: row.path, to: current.path));
        if (!current.message.hasValue && row.message.hasValue) {
          current.message.target = row.message.target;
          Database.attachments.put(current);
        }
        Database.attachments.remove(row.id!);
        continue;
      }
      final from = row.directory;
      row.guid = newGuid;
      moves.add((from: from, to: row.directory));
      Database.attachments.put(row);
    }
    return moves;
  }

  /// Moves the files [adoptRekeyedGuids] renamed the rows of. Nothing is overwritten, and a file that can't move
  /// downloads again under its new guid.
  static void moveRekeyedFiles(List<RekeyedFileMove> moves) {
    for (final move in moves) {
      try {
        final type = FileSystemEntity.typeSync(move.from);
        final taken = FileSystemEntity.typeSync(move.to) != FileSystemEntityType.notFound;
        if (type == FileSystemEntityType.notFound || taken) continue;
        if (type == FileSystemEntityType.directory) {
          Directory(move.from).renameSync(move.to);
        } else {
          File(move.to).parent.createSync(recursive: true);
          File(move.from).renameSync(move.to);
        }
      } catch (e) {
        Logger.warn("Couldn't move ${move.from} to ${move.to}", error: e, tag: "AttachmentActions");
      }
    }
  }

  static Attachment? findOne(String guid) {
    final queryBuilder = Database.attachments.query(Attachment_.guid.equals(guid));
    queryBuilder.link(Attachment_.message);
    final query = queryBuilder.build();
    query.limit = 1;
    final result = query.findFirst();
    query.close();
    return result;
  }

  static Future<int> saveAttachmentAsync(dynamic data) async {
    final attachmentData = data['attachmentData'] as Map<String, dynamic>;
    final messageData = data['messageData'] as Map<String, dynamic>?;

    final moves = <RekeyedFileMove>[];
    final id = Database.runInTransaction(TxMode.write, () {
      final attachment = Attachment.fromMap(attachmentData);
      moves.addAll(adoptRekeyedGuids([attachment]));

      /// Find an existing attachment with message relationship loaded
      Attachment? existing = AttachmentActions.findOne(attachment.guid!);
      if (existing != null) {
        attachment.id = existing.id;

        // Always preserve the existing message relationship unless explicitly overridden
        if (existing.message.hasValue) {
          attachment.message.target = existing.message.target;
        }
      }

      try {
        /// Override with new message link if provided
        if (messageData != null) {
          final message = Message.fromMap(messageData);
          if (message.id != null) {
            attachment.message.target = message;
          }
        }

        attachment.id = Database.attachments.put(attachment);
      } on UniqueViolationException catch (_) {}

      // Return just the ID for efficient transfer across isolates
      return attachment.id!;
    });
    moveRekeyedFiles(moves);
    return id;
  }

  static Future<void> bulkSaveAttachmentsAsync(dynamic data) async {
    final mapData = data['mapData'] as Map<Map<String, dynamic>, List<Map<String, dynamic>>>;

    // Convert the map from serialized data back to Message/Attachment objects
    Map<Message, List<Attachment>> map = {};
    for (var entry in mapData.entries) {
      final message = Message.fromMap(entry.key);
      final attachments = entry.value.map((e) => Attachment.fromMap(e)).toList();
      map[message] = attachments;
    }

    /// convert List<List<Attachment>> into just List<Attachment> (flatten it)
    final attachments = map.values.flattened.toList();
    moveRekeyedFiles(adoptRekeyedGuids(attachments));

    /// find existing attachments using query descriptor
    final guids = attachments.map((e) => e.guid!).toList();
    final queryDescriptor = AttachmentQueryDescriptor(
      conditions: [
        AttachmentQueryCondition(
          field: AttachmentQueryField.guid,
          operator: AttachmentQueryOperator.oneOf,
          value: guids,
        ),
      ],
    );

    List<Attachment> existingAttachments = await Attachment.findAsync(
      queryDescriptor: queryDescriptor,
    );

    return Database.runInTransaction(TxMode.write, () {
      /// map existing attachment IDs and preserve message relationships
      for (Attachment a in attachments) {
        final existing = existingAttachments.firstWhereOrNull((e) => e.guid == a.guid);
        if (existing != null) {
          a.id = existing.id;

          // Preserve the existing message relationship to prevent it from being cleared by put
          if (existing.message.hasValue && !a.message.hasValue) {
            a.message.target = existing.message.target;
          }
        }
      }

      try {
        /// store the attachments and update their ids
        final ids = Database.attachments.putMany(attachments);
        for (int i = 0; i < attachments.length; i++) {
          attachments[i].id = ids[i];
        }
      } on UniqueViolationException catch (_) {}
    });
  }

  static Future<int> replaceAttachmentAsync(dynamic data) async {
    final oldGuid = data['oldGuid'] as String;
    final newAttachmentData = data['newAttachmentData'] as Map<String, dynamic>;

    return Database.runInTransaction(TxMode.write, () {
      final newAttachment = Attachment.fromMap(newAttachmentData);

      Attachment? existing = AttachmentActions.findOne(oldGuid);
      if (existing == null) {
        throw Exception("Old GUID ($oldGuid) does not exist!");
      }

      // Note: cm and cvc services are NOT called here since they're only available on UI thread
      // This should be handled by the caller on the main thread before/after calling this

      // Guard against a race: another async path may have already inserted newAttachment.guid
      // between the caller's findOneAsync check and this transaction. If so, merge the new
      // fields into the conflicting record (preserving its ID so existing UI references stay
      // valid), then remove the stale temp-guid record.
      final conflicting = AttachmentActions.findOne(newAttachment.guid!);
      if (conflicting != null && conflicting.id != existing.id) {
        conflicting.originalROWID = newAttachment.originalROWID;
        conflicting.uti = newAttachment.uti;
        conflicting.mimeType = newAttachment.mimeType ?? conflicting.mimeType;
        conflicting.isOutgoing = newAttachment.isOutgoing;
        conflicting.transferName = newAttachment.transferName;
        conflicting.totalBytes = newAttachment.totalBytes;
        conflicting.bytes = newAttachment.bytes;
        conflicting.webUrl = newAttachment.webUrl;
        conflicting.hasLivePhoto = newAttachment.hasLivePhoto;
        Database.attachments.put(conflicting);
        Database.attachments.remove(existing.id!);

        newAttachment.id = conflicting.id;
        newAttachment.width = conflicting.width;
        newAttachment.height = conflicting.height;
        newAttachment.metadata = conflicting.metadata;
        return newAttachment.id!;
      }

      // update values and save
      existing.guid = newAttachment.guid;
      existing.originalROWID = newAttachment.originalROWID;
      existing.uti = newAttachment.uti;
      existing.mimeType = newAttachment.mimeType ?? existing.mimeType;
      existing.isOutgoing = newAttachment.isOutgoing;
      existing.transferName = newAttachment.transferName;
      existing.totalBytes = newAttachment.totalBytes;
      existing.bytes = newAttachment.bytes;
      existing.webUrl = newAttachment.webUrl;
      existing.hasLivePhoto = newAttachment.hasLivePhoto;
      // Use synchronous put within the transaction to preserve the message relationship.
      // saveAsync(null) would run outside this transaction and would fail to find the
      // attachment by the new guid (since DB still has the old guid), stripping the
      // message.targetId link and causing the conversation tile subtitle to show blank.
      Database.attachments.put(existing);

      // grab values from existing
      newAttachment.id = existing.id;
      newAttachment.width = existing.width;
      newAttachment.height = existing.height;
      newAttachment.metadata = existing.metadata;

      // Return just the ID for efficient transfer across isolates
      return newAttachment.id!;
    });
  }

  static Future<int?> findOneAttachmentAsync(dynamic data) async {
    final guid = data['guid'] as String;

    return Database.runInTransaction(TxMode.read, () {
      final attachmentBox = Database.attachments;

      final queryBuilder = attachmentBox.query(Attachment_.guid.equals(guid));
      queryBuilder.link(Attachment_.message);
      final query = queryBuilder.build();
      query.limit = 1;
      final result = query.findFirst();
      query.close();

      // Return just the ID for efficient transfer across isolates
      return result?.id;
    });
  }

  static Future<List<int>> findAttachmentsAsync(dynamic data) async {
    final queryDescriptorMap = data['queryDescriptor'] as Map<String, dynamic>?;

    return Database.runInTransaction(TxMode.read, () {
      final attachmentBox = Database.attachments;

      // Build condition from descriptor if provided
      final Condition<Attachment>? condition =
          queryDescriptorMap != null ? AttachmentQueryDescriptor.fromMap(queryDescriptorMap).buildCondition() : null;

      final queryBuilder = condition != null ? attachmentBox.query(condition) : attachmentBox.query();
      queryBuilder.link(Attachment_.message);
      final query = queryBuilder.build();
      final results = query.find();
      query.close();

      // Return just the IDs for efficient transfer across isolates
      return results.map((e) => e.id!).toList();
    });
  }

  static Future<void> deleteAttachmentAsync(dynamic data) async {
    final guid = data['guid'] as String;

    return Database.runInTransaction(TxMode.write, () {
      final query = Database.attachments.query(Attachment_.guid.equals(guid)).build();
      final result = query.findFirst();
      query.close();

      if (result?.id != null) {
        Database.attachments.remove(result!.id!);
      }
    });
  }
}
