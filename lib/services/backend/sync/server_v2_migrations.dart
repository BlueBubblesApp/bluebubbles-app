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

  /// Returns how many messages were updated, or null if a request failed or the server doesn't send v2 data.
  static Future<int?> run() => _backfillTapbackEmoji();

  static Future<int?> _backfillTapbackEmoji() async {
    final query = Database.messages
        .query(Message_.associatedMessageType
            .equals(ReactionTypes.EMOJI)
            .and(Message_.associatedMessageEmoji.isNull())
            .and(Message_.guid.notNull()))
        .build();
    final missing = await runAsync(() => query.find());
    query.close();

    int filled = 0;
    for (final reaction in missing) {
      try {
        final response = await HttpSvc.message.fetchOne(reaction.guid!);
        final data = response.data['data'] as Map?;
        // A server that doesn't send the field won't for any of the others either
        if (data == null || !data.containsKey('associatedMessageEmoji')) return null;
        final emoji = data['associatedMessageEmoji'] as String?;
        if (emoji == null) continue;

        reaction.associatedMessageEmoji = emoji;
        Database.messages.put(reaction);
        filled++;
        final chatGuid = reaction.chat.target?.guid;
        if (chatGuid != null && reaction.associatedMessageGuid != null) {
          maybeFindMessagesSvc(chatGuid)
              ?.getMessageStateIfExists(reaction.associatedMessageGuid!)
              ?.addAssociatedMessageInternal(reaction);
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
