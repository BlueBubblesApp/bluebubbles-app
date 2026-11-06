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

  /// Returns how many messages were updated, or null if the server couldn't be reached or isn't v2. A message whose
  /// own request fails is skipped and left for a manual run. Joins a pass that's already running rather than starting
  /// a second.
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
    int failed = 0;
    for (final reaction in missing) {
      final Response response;
      try {
        response = await HttpSvc.message.fetchOne(reaction.guid!);
      } catch (e, s) {
        if (_isNotFound(e)) continue;
        if (_isConnectionFailure(e)) {
          // Every later request would fail the same way; the next launch retries the rest
          Logger.warn("Stopped backfilling tapback emoji: couldn't reach the server",
              error: e, trace: s, tag: "ServerV2Migrations");
          return null;
        }
        // Only this message: skip it rather than let it block the rest on every launch
        failed++;
        Logger.warn("Failed to backfill emoji for tapback ${reaction.guid}",
            error: e, trace: s, tag: "ServerV2Migrations");
        continue;
      }

      // The server leaves the key out when chat.db has no emoji for this one, so skip it
      final emoji = (response.data['data'] as Map?)?['associatedMessageEmoji'] as String?;
      if (emoji == null) continue;

      // Re-read, so anything saved to it while the request was out isn't overwritten
      final updated = Database.messages.get(reaction.id!);
      if (updated == null) continue;
      updated.associatedMessageEmoji = emoji;
      Database.messages.put(updated);
      filled++;

      final chatGuid = updated.chat.target?.guid;
      if (chatGuid != null && updated.associatedMessageGuid != null) {
        maybeFindMessagesSvc(chatGuid)
            ?.getMessageStateIfExists(updated.associatedMessageGuid!)
            ?.addAssociatedMessageInternal(updated);
      }
    }
    if (failed > 0) {
      Logger.warn("Skipped $failed tapback(s) whose emoji couldn't be fetched", tag: "ServerV2Migrations");
    }
    return filled;
  }

  /// The message is gone from the server. The status alone can also come from a tunnel or proxy, but either way
  /// there's nothing to fetch for this one.
  static bool _isNotFound(Object e) =>
      e is Response && (e.statusCode == 404 || '${e.data}'.contains('Message does not exist!'));

  /// Whether [e] means no request will get through right now: no server URL, no response at all (offline, refused,
  /// timed out), a rejected password, or a proxy or tunnel that can't reach the server (502 and up; the server's own
  /// errors are 500).
  static bool _isConnectionFailure(Object e) {
    if (e is String) return true; // runApiGuarded's "No server URL!"
    final status = e is Response ? e.statusCode : (e is DioException ? e.response?.statusCode : null);
    if (status == 401 || (status != null && status >= 502)) return true;
    if (e is DioException) return e.response == null;
    if (e is Response) {
      // ApiInterceptor resolves a timeout into a synthesized 500 with this error type
      final error = e.data is Map ? (e.data as Map)['error'] : null;
      return error is Map && error['type'] == 'timeout';
    }
    return false;
  }
}
