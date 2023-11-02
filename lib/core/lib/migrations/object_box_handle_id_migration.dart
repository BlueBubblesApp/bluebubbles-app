import 'package:bluebubbles/core/abstractions/storage/migration.dart';
import 'package:bluebubbles/core/services/services.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:get/get.dart';

class ObjectBoxHandleIdMigration extends Migration {
  @override
  String name = "ObjectBox-ConvertHandleIds";

  @override
  String description = "Migrate the `handleId` field to match the server-side ROWID, rather than the client site ROWID";

  @override
  int version = 2;

  @override
  Future<void> execute() {
    final messages = db.messages.getAll();
    if (messages.isNotEmpty) {
      final handles = db.handles.getAll();
      log.debug("Replacing handleIds for ${handles.length} messages...");
      for (Message m in messages) {
        if (m.isFromMe! || m.handleId == 0 || m.handleId == null) continue;
        m.handleId = handles.firstWhereOrNull((e) => e.id == m.handleId)?.originalROWID ?? m.handleId;
      }

      log.info("Applying changes to the database...");
      db.messages.putMany(messages);
    }

    return Future.value();
  }
}