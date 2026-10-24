import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

/// How many chats to ask the server for at a time. Matches the page size the
/// rest of the app uses for `/chat/query`.
const int kSpamBackfillPageSize = 200;

/// Copies Messages' Spam verdict from freshly fetched server chats onto the
/// matching stored chats, and returns only the ones that actually changed.
///
/// Only the spam flag is taken. Pin, mute, archive and unread are owned by the
/// device on Android, so merging the whole payload would undo the user's own
/// organising. [Chat.mergeSpamFlag] additionally ignores a payload that omits
/// the key entirely, so a server that predates the flag cannot erase a verdict
/// that is already stored.
List<Chat> applySpamFlagsFromServer({required List<Chat> stored, required List<Chat> serverChats}) {
  if (stored.isEmpty || serverChats.isEmpty) return const [];

  final byGuid = <String, Chat>{};
  for (final chat in serverChats) {
    byGuid[chat.guid] = chat;
  }

  final changed = <Chat>[];
  for (final chat in stored) {
    final fromServer = byGuid[chat.guid];
    if (fromServer == null) continue;
    if (chat.mergeSpamFlag(fromServer)) changed.add(chat);
  }

  return changed;
}

/// Backfills the Spam verdict for chats that were already stored before the
/// server started reporting it.
///
/// Without this, `isFilteredAsSpam` is only written when server data for a chat
/// happens to arrive — a new message, or a full sync — so an existing install
/// shows an empty Spam list indefinitely and a fresh install shows one until
/// every spam sender writes again.
///
/// Runs in the background after the chat list is already on screen, pages the
/// query so a library of thousands of chats never arrives as one response, and
/// writes only the rows whose verdict actually moved. Re-running it is a no-op.
class SpamFlagBackfill {
  static bool _running = false;

  /// Set once the backfill has completed against the current server, so the
  /// cost is paid once per launch rather than on every reconnect.
  static bool _completedThisSession = false;

  static void resetForTesting() {
    _running = false;
    _completedThisSession = false;
  }

  static Future<void> run({int pageSize = kSpamBackfillPageSize}) async {
    if (_running || _completedThisSession) return;
    _running = true;

    try {
      var offset = 0;
      var updated = 0;

      while (true) {
        final response = await HttpSvc.chat.query(offset: offset, limit: pageSize, sort: "lastmessage");
        final rows = response.data['data'];
        if (rows is! List || rows.isEmpty) break;

        final serverChats = rows
            .whereType<Map>()
            .map((e) => Chat.fromMap(e.cast<String, Object>()))
            .toList();

        // A server that predates the flag sends no value at all. Stopping here
        // avoids paging the entire chat list to learn nothing.
        if (offset == 0 && serverChats.every((chat) => chat.isFilteredAsSpam == null)) {
          Logger.info("Server does not report the Spam flag; skipping backfill", tag: "SpamFlagBackfill");
          return;
        }

        final stored = <Chat>[];
        for (final chat in serverChats) {
          final existing = Chat.findOne(guid: chat.guid);
          if (existing != null) stored.add(existing);
        }

        final changed = applySpamFlagsFromServer(stored: stored, serverChats: serverChats);
        if (changed.isNotEmpty) {
          Database.chats.putMany(changed);
          for (final chat in changed) {
            ChatsSvc.updateChat(chat);
          }
          updated += changed.length;
        }

        if (rows.length < pageSize) break;
        offset += pageSize;
      }

      _completedThisSession = true;
      if (updated > 0) {
        Logger.info("Backfilled the Spam verdict for $updated chat(s)", tag: "SpamFlagBackfill");
      }
    } catch (error, trace) {
      // A failed backfill is not worth surfacing: the flag still arrives with
      // the next message in each chat, and the next launch retries.
      Logger.warn("Failed to backfill Spam verdicts", error: error, trace: trace, tag: "SpamFlagBackfill");
    } finally {
      _running = false;
    }
  }
}
