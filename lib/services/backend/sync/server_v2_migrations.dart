import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';

/// Fills in data that servers older than v2 never sent, for messages already synced from them.
/// Sync never refetches old messages, so this has to ask the server again.
class ServerV2Migrations {
  /// Run on startup: once the server is known to be v2, and on each launch until a pass gets through.
  static Future<void> runOnce() async {
    if (PrefsSvc.database.getServerV2MigrationsDone() || !SettingsSvc.serverDetails.isV2Server) return;
    if (await run() != null) await PrefsSvc.database.setServerV2MigrationsDone();
  }

  static Future<int?>? _running;

  /// Returns how many messages were updated, or null if a request failed or the server isn't v2. Joins a pass that's
  /// already running rather than starting a second.
  static Future<int?> run() => _running ??= _run().whenComplete(() => _running = null);

  static Future<int?> _run() async {
    if (!SettingsSvc.serverDetails.isV2Server) return null;
    return _backfillTapbackEmoji();
  }

  /// Whether [message] is on the server, rather than a local one still sending or that failed to.
  static bool _isOnServer(Message message) => !message.guid!.startsWith("temp") && !message.guid!.startsWith("error");

  static Future<int?> _backfillTapbackEmoji() async {
    final query = Database.messages
        .query(Message_.associatedMessageType
            .oneOf([ReactionTypes.EMOJI, ReactionTypes.REMOVED_EMOJI])
            .and(Message_.associatedMessageEmoji.isNull())
            .and(Message_.guid.notNull()))
        .build();
    final missing = (await runAsync(() => query.find())).where(_isOnServer).toList();
    query.close();

    int filled = 0;
    for (final reaction in missing) {
      try {
        final response = await HttpSvc.message.fetchOne(reaction.guid!);
        // The server leaves the key out when chat.db has no emoji for this one, so skip it
        final emoji = (response.data['data'] as Map?)?['associatedMessageEmoji'] as String?;
        if (emoji == null) continue;

        // Re-read, so anything saved to it while the request was out isn't overwritten
        final current = Database.messages.get(reaction.id!);
        if (current == null) continue;
        current.associatedMessageEmoji = emoji;
        Database.messages.put(current);
        filled++;
        final chatGuid = current.chat.target?.guid;
        if (chatGuid != null && current.associatedMessageGuid != null) {
          maybeFindMessagesSvc(chatGuid)
              ?.getMessageStateIfExists(current.associatedMessageGuid!)
              ?.addAssociatedMessageInternal(current);
        }
      } catch (e, s) {
        // Tunnels and proxies can also return a 404, so only the server's own error means the message is gone.
        // Anything else retries next launch; stop now rather than wait out a timeout per message.
        if (e is Response && '${e.data}'.contains('Message does not exist!')) continue;
        Logger.warn("Failed to backfill emoji for tapback ${reaction.guid}",
            error: e, trace: s, tag: "ServerV2Migrations");
        return null;
      }
    }
    return filled;
  }
}
