import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:dio/dio.dart';

/// Fills in data that servers older than v2 never sent, for messages already synced from them.
/// Sync never refetches old messages, so this has to ask the server again.
class ServerV2Migrations {
  /// Run manually from Developer Tools. Returns how many messages were updated,
  /// or null if the server doesn't send v2 data.
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
        final emoji = response.data['data']?['associatedMessageEmoji'] as String?;
        // A server that doesn't send the field won't for any of the others either
        if (emoji == null) return null;

        reaction.associatedMessageEmoji = emoji;
        Database.messages.put(reaction);
        filled++;
        final chatGuid = reaction.chat.target?.guid;
        if (chatGuid != null && reaction.associatedMessageGuid != null) {
          maybeFindMessagesSvc(chatGuid)
              ?.getMessageStateIfExists(reaction.associatedMessageGuid!)
              ?.addAssociatedMessageInternal(reaction);
        }
      } on DioException catch (e) {
        Logger.warn("Failed to backfill emoji for tapback ${reaction.guid}: $e", tag: "ServerV2Migrations");
      }
    }
    return filled;
  }
}
