import 'dart:convert';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

/// A validated `message-deleted` / `message-restored` event.
class RecoverableMessageEvent {
  const RecoverableMessageEvent({
    required this.chatGuid,
    required this.messageGuid,
    required this.deleted,
  });

  final String chatGuid;
  final String messageGuid;

  /// True for `message-deleted`, false for `message-restored`.
  final bool deleted;
}

/// Validates a live Recently Deleted event payload.
///
/// Returns null for anything malformed. Both GUIDs are required: acting on a
/// half-formed event would either hide the wrong message or hide nothing while
/// reporting success.
RecoverableMessageEvent? parseRecoverableMessageEvent(dynamic data, {required bool deleted}) {
  if (data is! Map) return null;

  final chatGuid = data['chatGuid'];
  final messageGuid = data['messageGuid'];
  if (chatGuid is! String || chatGuid.isEmpty) return null;
  if (messageGuid is! String || messageGuid.isEmpty) return null;

  return RecoverableMessageEvent(chatGuid: chatGuid, messageGuid: messageGuid, deleted: deleted);
}

/// A parsed `/server/recoverable-messages/snapshot` response.
class RecoverableMessageSnapshot {
  const RecoverableMessageSnapshot({
    this.deletedByChat = const {},
    this.generatedAt = 0,
    this.skipped = false,
    this.reason,
  });

  final Map<String, Set<String>> deletedByChat;
  final int generatedAt;
  final bool skipped;
  final String? reason;

  Set<String> get allDeletedGuids => deletedByChat.values.expand((guids) => guids).toSet();
}

/// What the catch-up pass should change locally.
class RecoverableMessageActions {
  const RecoverableMessageActions({
    this.toHide = const {},
    this.toRestore = const {},
    this.nextBaseline = const {},
    this.seeded = false,
  });

  final Set<String> toHide;
  final Set<String> toRestore;

  /// The GUIDs this client is hiding on Apple's behalf after this pass.
  final Set<String> nextBaseline;

  /// Whether this pass only established a baseline and changed nothing.
  final bool seeded;

  bool get isEmpty => toHide.isEmpty && toRestore.isEmpty;
}

/// Parses an Apple-authoritative Recently Deleted snapshot.
///
/// Anything unexpected refuses the ENTIRE snapshot rather than applying part of
/// it. The snapshot is what licenses the client to un-hide messages, so a
/// truncated or malformed response must never be read as "Apple deleted
/// nothing" and undo deletions the user actually made.
///
/// Kept free of Logger (which resolves a GetIt singleton) so it stays unit
/// testable; the caller logs the refusal reason.
RecoverableMessageSnapshot parseRecoverableMessageSnapshot(Map<String, dynamic> payload) {
  if (payload['schemaVersion'] != 1) {
    return const RecoverableMessageSnapshot(skipped: true, reason: 'schema');
  }
  if (payload['complete'] != true) {
    return const RecoverableMessageSnapshot(skipped: true, reason: 'incomplete');
  }

  final generatedAt = payload['generatedAt'];
  if (generatedAt is! int || generatedAt < 0) {
    return const RecoverableMessageSnapshot(skipped: true, reason: 'malformed');
  }

  final rawChats = payload['chats'];
  if (rawChats is! List) {
    return const RecoverableMessageSnapshot(skipped: true, reason: 'malformed');
  }

  final deletedByChat = <String, Set<String>>{};
  for (final raw in rawChats) {
    if (raw is! Map) {
      return const RecoverableMessageSnapshot(skipped: true, reason: 'malformed');
    }
    final guid = raw['guid'];
    final rawGuids = raw['deletedMessageGuids'];
    if (guid is! String || guid.isEmpty || rawGuids is! List) {
      return const RecoverableMessageSnapshot(skipped: true, reason: 'malformed');
    }
    if (rawGuids.any((messageGuid) => messageGuid is! String || messageGuid.isEmpty)) {
      return const RecoverableMessageSnapshot(skipped: true, reason: 'malformed');
    }
    deletedByChat.putIfAbsent(guid, () => <String>{}).addAll(rawGuids.cast<String>());
  }

  return RecoverableMessageSnapshot(deletedByChat: deletedByChat, generatedAt: generatedAt);
}

/// Works out the minimum set of local changes that makes the device agree with
/// Apple's Recently Deleted folder.
///
/// Forward-only, like ChatStateReconciler. [baselineGuids] is what this client
/// previously hid on Apple's behalf, and ONLY those GUIDs are ever un-hidden:
/// a message the user deleted inside the app is also `dateDeleted`, and Apple
/// never had it in Recently Deleted, so treating every hidden row as a
/// candidate would resurrect the user's own deletions on the next sync.
///
/// The first pass against a server seeds that baseline and changes nothing,
/// so installing the feature never rewrites existing history.
///
/// Both directions are restricted to messages the device actually holds: a
/// deleted message that was never downloaded is nothing to hide, and a hidden
/// row the device no longer has is nothing to restore.
RecoverableMessageActions resolveRecoverableMessageActions({
  required bool hasTrustedBaseline,
  required Set<String> baselineGuids,
  required Set<String> serverDeletedGuids,
  required Set<String> locallyHiddenGuids,
  required Set<String> locallyKnownGuids,
}) {
  final nextBaseline = serverDeletedGuids.where(locallyKnownGuids.contains).toSet();

  if (!hasTrustedBaseline) {
    return RecoverableMessageActions(nextBaseline: nextBaseline, seeded: true);
  }

  final toHide = serverDeletedGuids
      .where((guid) => locallyKnownGuids.contains(guid) && !locallyHiddenGuids.contains(guid))
      .toSet();
  final toRestore = baselineGuids
      .where((guid) =>
          locallyKnownGuids.contains(guid) &&
          locallyHiddenGuids.contains(guid) &&
          !serverDeletedGuids.contains(guid))
      .toSet();

  return RecoverableMessageActions(toHide: toHide, toRestore: toRestore, nextBaseline: nextBaseline);
}

/// Brings locally stored messages back in line with Apple's Recently Deleted
/// folder after the client has been offline.
///
/// The live `message-deleted` / `message-restored` events cover everything that
/// happens while connected; this covers the gap, the same way
/// ChatStateReconciler does for chats.
class RecoverableMessageReconciler {
  /// Reads the GUIDs this client is hiding on Apple's behalf.
  ///
  /// The baseline is deliberately NOT keyed to the server address. Message
  /// GUIDs are minted by Apple and are stable for the same Messages database,
  /// while the address is not: a Cloudflare/ngrok quick tunnel mints a new URL
  /// on every server restart. Keying on it made the baseline untrusted after
  /// each restart, which re-seeded and silently disabled this catch-up — the
  /// offline case it exists for. A migration path keeps older baselines that
  /// still carry an address.
  static ({bool trusted, Set<String> guids}) readBaseline() {
    final raw = PrefsSvc.database.getRecoverableMessageBaseline();
    if (raw == null) return (trusted: false, guids: <String>{});

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('malformed baseline');
      final guids = decoded['guids'];
      if (guids is! List || guids.any((guid) => guid is! String || guid.isEmpty)) {
        throw const FormatException('malformed baseline guid');
      }
      return (trusted: true, guids: guids.cast<String>().toSet());
    } catch (error, trace) {
      Logger.warn('Recently Deleted baseline was malformed; reseeding',
          error: error, trace: trace, tag: 'RecoverableMessageReconciler');
      return (trusted: false, guids: <String>{});
    }
  }

  static Future<void> saveBaseline(Set<String> guids) {
    final sorted = guids.toList()..sort();
    return PrefsSvc.database.setRecoverableMessageBaseline(
      jsonEncode({'guids': sorted}),
    );
  }

  /// Applies one catch-up hide/restore through the same service path the live
  /// events use, so the message struct, the chat's latest-message pointer and
  /// the conversation tile all stay consistent with the database.
  ///
  /// Falls back to a direct database write when the message's chat is missing
  /// locally: there is no view to update in that case, and refusing would leave
  /// Apple's deletion unapplied.
  static Future<void> _applyThroughService(String guid, {required bool hide}) async {
    final message = Message.findOne(guid: guid);
    final chatGuid = message?.chat.target?.guid;

    if (message == null || chatGuid == null) {
      if (hide) {
        await Message.softDelete(guid);
      } else {
        await Message.restore(guid);
      }
      return;
    }

    final service = MessagesSvc(chatGuid);
    if (hide) {
      await service.softDeleteMessage(message);
    } else {
      await service.restoreMessage(message);
    }
  }

  static Future<void> run() async {
    try {
      final response = await HttpSvc.server.getRecoverableMessageSnapshot();
      final payload = response.data['data'];
      if (payload is! Map) return;

      final snapshot = parseRecoverableMessageSnapshot(payload.cast<String, dynamic>());
      if (snapshot.skipped) {
        Logger.warn(
          'Refusing to reconcile Recently Deleted (${snapshot.reason})',
          tag: 'RecoverableMessageReconciler',
        );
        return;
      }

      final serverDeleted = snapshot.allDeletedGuids;

      final hiddenQuery = Database.messages.query(Message_.dateDeleted.notNull()).build();
      final hidden = hiddenQuery.find();
      hiddenQuery.close();
      final locallyHidden = hidden.map((message) => message.guid!).toSet();

      // Only messages the device already holds can be hidden or restored.
      final knownGuids = {...locallyHidden};
      for (final guid in serverDeleted) {
        if (Message.findOne(guid: guid) != null) knownGuids.add(guid);
      }

      final baseline = readBaseline();

      final actions = resolveRecoverableMessageActions(
        hasTrustedBaseline: baseline.trusted,
        baselineGuids: baseline.guids,
        serverDeletedGuids: serverDeleted,
        locallyHiddenGuids: locallyHidden,
        locallyKnownGuids: knownGuids,
      );

      // Route through MessagesService, exactly as the live `message-deleted` /
      // `message-restored` events do. Writing dateDeleted straight to the
      // database hides the row but leaves the already-built message struct and
      // the conversation tile's latestMessage pointer untouched, so the thread
      // renders empty while its tile still previews the hidden message.
      for (final guid in actions.toHide) {
        await _applyThroughService(guid, hide: true);
      }
      for (final guid in actions.toRestore) {
        await _applyThroughService(guid, hide: false);
      }

      // Commit only after every local change succeeded, so a partial failure
      // retries from the previous known-good baseline.
      await saveBaseline(actions.nextBaseline);

      if (actions.seeded) {
        Logger.info('Seeded the Recently Deleted baseline (${actions.nextBaseline.length} message(s))',
            tag: 'RecoverableMessageReconciler');
      } else if (!actions.isEmpty) {
        Logger.info(
          'Reconciled Recently Deleted: ${actions.toHide.length} hidden, ${actions.toRestore.length} restored',
          tag: 'RecoverableMessageReconciler',
        );
      }
    } catch (error, trace) {
      // A server below Ventura answers with UNSUPPORTED_MACOS_VERSION, which is
      // expected rather than a fault. Either way the live events still work and
      // the next launch retries.
      Logger.warn('Failed to reconcile Recently Deleted',
          error: error, trace: trace, tag: 'RecoverableMessageReconciler');
    }
  }
}
