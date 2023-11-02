import 'package:bluebubbles/core/abstractions/storage/migration.dart';
import 'package:bluebubbles/core/services/services.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/backend/settings/settings_service.dart';

class ObjectBoxNullifyFieldsMigration extends Migration {
  @override
  String name = "ObjectBox-NullifyFields";

  @override
  String description = "Reset the autoSendReadReceipts and autoSendTypingIndicators fields to null in some conditions.";

  @override
  int version = 3;

  @override
  Future<void> execute() {
    final chats = db.chats.getAll();
    final papi = ss.settings.enablePrivateAPI.value;
    final typeGlobal = ss.settings.privateSendTypingIndicators.value;
    final readGlobal = ss.settings.privateMarkChatAsRead.value;
    for (Chat c in chats) {
      if (papi && readGlobal && !(c.autoSendReadReceipts ?? true)) {
        // dont do anything
      } else {
        c.autoSendReadReceipts = null;
      }
      if (papi && typeGlobal && !(c.autoSendTypingIndicators ?? true)) {
        // dont do anything
      } else {
        c.autoSendTypingIndicators = null;
      }
    }

    return Future.value();
  }
}