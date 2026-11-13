import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/actions/attachment_actions.dart';
import 'package:bluebubbles/services/backend/actions/message_actions.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' show Rxn;

/// What a migration pass is doing, and how far through it is (0 to 1).
typedef ServerV2MigrationProgress = void Function(String step, double progress, {int? completed, int? total});
typedef ServerV2MigrationStatus = ({
  String step,
  double? progress,
  int stepNumber,
  List<double?> steps,
  int? completed,
  int? total,
});

/// Backfills server-only fields and message changes older clients could not recover.
class ServerV2Migrations {
  /// Bump when adding a backfill, so clients that finished the earlier ones run again.
  static const int version = 5;

  /// Run on startup: once the server is known to be v2, and on each launch until a pass gets through.
  static Future<void> runOnce() async {
    if (PrefsSvc.database.getServerV2MigrationsVersion() >= version || !SettingsSvc.serverDetails.isV2Server) return;
    if (await run() != null) await PrefsSvc.database.setServerV2MigrationsVersion(version);
  }

  static Future<int?>? _running;
  static final progress = Rxn<ServerV2MigrationStatus>();

  /// Returns how many messages were updated, or null if the server couldn't be reached or isn't v2. A message whose
  /// own request fails is skipped and left for a manual run. Joins a pass that's already running rather than starting
  /// a second.
  static Future<int?> run({ServerV2MigrationProgress? onProgress}) {
    final future = _running ??= _runWithProgress();
    if (onProgress == null) return future;
    final subscription = progress.listen((status) {
      if (status != null && status.progress != null) {
        onProgress(status.step, status.progress!, completed: status.completed, total: status.total);
      }
    });
    final status = progress.value;
    if (status != null && status.progress != null) {
      onProgress(status.step, status.progress!, completed: status.completed, total: status.total);
    }
    return future.whenComplete(subscription.cancel);
  }

  static const stepNames = ['Emoji tapbacks', 'Stickers', 'iMessage apps', 'Message changes'];

  /// A reconnect can arrive before the failed request has finished unwinding.
  static Future<void> retryAfterReconnect() async {
    final pending = _running;
    if (pending != null) {
      try {
        if (await pending != null) return;
      } catch (e, s) {
        Logger.warn('Previous v2 migration failed', error: e, trace: s, tag: 'ServerV2Migrations');
      }
    }
    await runOnce();
  }

  static Future<int?> _runWithProgress() async {
    final steps = List<double?>.filled(stepNames.length, 0);
    Future<int?> runStep(int index, Future<int?> Function(ServerV2MigrationProgress) work) async {
      void report(String step, double? value, {int? completed, int? total}) {
        steps[index] = value;
        progress.value = (
          step: step,
          progress: value,
          stepNumber: index + 1,
          steps: List<double?>.unmodifiable(steps),
          completed: completed,
          total: total,
        );
      }

      report(stepNames[index], null);
      final result = await work(
        (step, value, {completed, total}) => report(step, value, completed: completed, total: total),
      );
      if (result != null) {
        final status = progress.value!;
        report(status.step, 1, completed: status.total, total: status.total);
      }
      return result;
    }

    try {
      if (!SettingsSvc.serverDetails.isV2Server) return null;
      final emoji = await runStep(0, _backfillTapbackEmoji);
      if (emoji == null) return null;
      final stickers = await runStep(1, _backfillStickerPlacement);
      if (stickers == null) return null;
      final apps = await runStep(2, (report) async {
        final payloads = await _backfillAppPayloads(
          (step, value, {completed, total}) => report(step, value * 0.9, completed: completed, total: total),
        );
        if (payloads == null) return null;
        final turns = await _backfillAppTurns(
          (step, value, {completed, total}) => report(step, 0.9 + value * 0.1, completed: completed, total: total),
        );
        return turns == null ? null : payloads + turns;
      });
      if (apps == null) return null;
      final changes = await runStep(3, _backfillMessageChanges);
      return changes == null ? null : emoji + stickers + apps + changes;
    } finally {
      progress.value = null;
      _running = null;
    }
  }

  /// Repairs changes older clients missed even when their date is already behind
  /// the regular sync marker. Creation history and normal markers are untouched.
  static Future<int?> _backfillMessageChanges(ServerV2MigrationProgress? onProgress) async {
    onProgress?.call("Updating missed message changes", 0);
    final guids = await runAsync(() => Database.runInTransaction(TxMode.read, () {
      final query = Database.messages.query(Message_.guid.notNull()).build();
      try {
        return query.property(Message_.guid).find()
            .where((guid) => guid.isNotEmpty && !guid.startsWith('temp') && !guid.startsWith('error'))
            .toSet().toList();
      } finally {
        query.close();
      }
    }));
    if (guids.isEmpty) return 0;
    Logger.info('Backfilling message changes for ${guids.length} local GUIDs', tag: 'ServerV2Migrations');
    final manager = IncrementalSyncManager(
      startTimestamp: 0,
      includeNewMessages: false,
      changeMessageGuids: guids,
      onProgress: onProgress,
    );
    try {
      await manager.start();
      return manager.messagesSynced;
    } catch (e, s) {
      Logger.warn(
        'Stopped backfilling message changes; retrying after reconnect or on the next launch',
        error: e,
        trace: s,
        tag: 'ServerV2Migrations',
      );
      return null;
    }
  }

  /// Game turns saved before the client mirrored Messages' rewrite of a replaced turn to type 3, so earlier turns of a
  /// game showed in full. Settled locally, as a new turn settles them: every stored type-2 turn retires the turns of
  /// its session it replaced. Returns how many were rewritten.
  static Future<int?> _backfillAppTurns(ServerV2MigrationProgress? onProgress) async {
    onProgress?.call("Updating iMessage app turns", 0);
    return runAsync(
      () => Database.runInTransaction(TxMode.write, () {
        final query = Database.messages
            .query(
              Message_.balloonBundleId
                  .contains(AppSessionTypes.extensionBalloonPlugin)
                  .and(Message_.associatedMessageType.equals(AppSessionTypes.UPDATE)),
            )
            .build();
        final turns = query.find();
        query.close();
        return turns.fold<int>(0, (retired, turn) => retired + MessageActions.retireEarlierTurns(turn).length);
      }),
    );
  }

  /// App balloons saved before the client kept their session, without their payload (as a push delivers them), or
  /// before sync asked for `appPayload`, whose session our archive decoding misses on some messages (a game's opening
  /// one). Re-fetched and re-parsed whole. A missing icon isn't checked: plenty of apps never send one.
  static Future<int?> _backfillAppPayloads(ServerV2MigrationProgress? onProgress) async {
    final query = Database.messages
        .query(Message_.balloonBundleId.contains(AppSessionTypes.extensionBalloonPlugin).and(Message_.guid.notNull()))
        .build();
    final stale = (await runAsync(() => query.find())).where(_isOnServer).where((message) {
      final app = message.payloadData?.appData?.firstOrNull;
      return app == null || app.sessionId == null;
    }).toList();
    query.close();

    int filled = 0;
    for (final (i, message) in stale.indexed) {
      onProgress?.call("Updating iMessage apps", i / stale.length, completed: i, total: stale.length);
      try {
        final response = await HttpSvc.message.fetchOne(message.guid!, withQuery: "payloadData,appPayload");
        final data = response.data['data'];
        if (data is! Map) continue;
        final fresh = Message.fromMap(Map<String, dynamic>.from(data)).payloadData;
        if (fresh?.appData?.firstOrNull == null) continue;

        // Re-read, so anything saved to it while the request was out isn't overwritten
        final current = Database.messages.get(message.id!);
        if (current == null) continue;
        current.payloadData = fresh;
        Database.messages.put(current);
        filled++;
      } catch (e, s) {
        if (_isConnectionFailure(e)) {
          Logger.warn(
            "Stopped backfilling app payloads at ${message.guid}",
            error: e,
            trace: s,
            tag: "ServerV2Migrations",
          );
          return null;
        }
        // One message the server can't give us (gone, 404, or anything else) shouldn't hold up the rest
        if (!_isNotFound(e)) {
          Logger.warn("Skipped the app payload of ${message.guid}", error: e, trace: s, tag: "ServerV2Migrations");
        }
      }
    }
    return filled;
  }

  /// Fills in `stickerPlacement` on placed stickers synced before the client kept it.
  static Future<int?> _backfillStickerPlacement(ServerV2MigrationProgress? onProgress) async {
    final query = Database.messages
        .query(Message_.associatedMessageType.equals("sticker").and(Message_.guid.notNull()))
        .build();
    final missing = (await runAsync(
      () => query.find(),
    )).where(_isOnServer).where((m) => m.dbAttachments.any((a) => a.stickerPlacement == null)).toList();
    query.close();

    int filled = 0;
    for (final (i, sticker) in missing.indexed) {
      onProgress?.call("Updating stickers", i / missing.length, completed: i, total: missing.length);
      try {
        final response = await HttpSvc.message.fetchOne(sticker.guid!, withQuery: "attachment");
        final remote = (((response.data['data'] as Map?)?['attachments'] as List?) ?? const [])
            .whereType<Map>()
            .map((a) => Attachment.fromMap(a.cast<String, dynamic>()))
            .toList();
        final moves = <RekeyedFileMove>[];
        var changed = false;
        final current = Database.runInTransaction(TxMode.write, () {
          moves.addAll(AttachmentActions.adoptRekeyedGuids(remote));
          final current = Database.messages.get(sticker.id!);
          if (current == null) return null;
          for (final a in current.dbAttachments) {
            final placement = remote.firstWhereOrNull((r) => r.guid == a.guid)?.stickerPlacement;
            if (a.stickerPlacement != null || placement == null) continue;
            a.stickerPlacement = placement;
            Database.attachments.put(a);
            changed = true;
          }
          return current;
        });
        AttachmentActions.moveRekeyedFiles(moves);
        if (current == null || !changed) continue;
        filled++;
        final chatGuid = current.chat.target?.guid;
        if (chatGuid != null && current.associatedMessageGuid != null) {
          maybeFindMessagesSvc(
            chatGuid,
          )?.getMessageStateIfExists(current.associatedMessageGuid!)?.addAssociatedMessageInternal(current);
        }
      } catch (e, s) {
        if (_isNotFound(e)) continue;
        if (_isConnectionFailure(e)) {
          // Every later request would fail the same way; the next launch retries the rest
          Logger.warn(
            "Stopped backfilling sticker placements: couldn't reach the server",
            error: e,
            trace: s,
            tag: "ServerV2Migrations",
          );
          return null;
        }
        // Only this message: skip it rather than let it block the rest on every launch
        Logger.warn(
          "Failed to backfill the placement of sticker ${sticker.guid}",
          error: e,
          trace: s,
          tag: "ServerV2Migrations",
        );
      }
    }
    return filled;
  }

  /// Whether [message] is on the server, rather than a local one still sending or that failed to.
  static bool _isOnServer(Message message) => !message.guid!.startsWith("temp") && !message.guid!.startsWith("error");

  static Future<int?> _backfillTapbackEmoji(ServerV2MigrationProgress? onProgress) async {
    final query = Database.messages
        .query(
          Message_.associatedMessageType
              .oneOf([ReactionTypes.EMOJI, ReactionTypes.REMOVED_EMOJI])
              .and(Message_.associatedMessageEmoji.isNull())
              .and(Message_.guid.notNull()),
        )
        .build();
    final missing = (await runAsync(() => query.find())).where(_isOnServer).toList();
    query.close();

    int filled = 0;
    int failed = 0;
    for (final (i, reaction) in missing.indexed) {
      onProgress?.call("Updating emoji tapbacks", i / missing.length, completed: i, total: missing.length);
      final Response response;
      try {
        response = await HttpSvc.message.fetchOne(reaction.guid!);
      } catch (e, s) {
        if (_isNotFound(e)) continue;
        if (_isConnectionFailure(e)) {
          // Every later request would fail the same way; the next launch retries the rest
          Logger.warn(
            "Stopped backfilling tapback emoji: couldn't reach the server",
            error: e,
            trace: s,
            tag: "ServerV2Migrations",
          );
          return null;
        }
        // Only this message: skip it rather than let it block the rest on every launch
        failed++;
        Logger.warn(
          "Failed to backfill emoji for tapback ${reaction.guid}",
          error: e,
          trace: s,
          tag: "ServerV2Migrations",
        );
        continue;
      }

      // The server leaves the key out when chat.db has no emoji for this one, so skip it
      final emoji = (response.data['data'] as Map?)?['associatedMessageEmoji'] as String?;
      if (emoji == null) continue;

      // Re-read inside the write, so anything saved to it while the request was out isn't overwritten
      final updated = Database.runInTransaction(TxMode.write, () {
        final current = Database.messages.get(reaction.id!);
        if (current == null) return null;
        current.associatedMessageEmoji = emoji;
        Database.messages.put(current);
        return current;
      });
      if (updated == null) continue;
      filled++;

      final chatGuid = updated.chat.target?.guid;
      if (chatGuid != null && updated.associatedMessageGuid != null) {
        maybeFindMessagesSvc(
          chatGuid,
        )?.getMessageStateIfExists(updated.associatedMessageGuid!)?.addAssociatedMessageInternal(updated);
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
