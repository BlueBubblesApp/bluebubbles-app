import 'dart:convert';

import 'package:flutter/foundation.dart';

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
/// A snapshot is stale when it was generated before the one whose result is
/// already stored. A baseline without a timestamp (older format, or none yet)
/// never makes a snapshot stale.
bool isStaleRecoverableSnapshot({required int snapshotGeneratedAt, required int baselineGeneratedAt}) =>
    baselineGeneratedAt > 0 && snapshotGeneratedAt > 0 && snapshotGeneratedAt < baselineGeneratedAt;

/// Decides a single live `message-deleted` / `message-restored` event.
///
/// A hide always applies and joins the baseline, so a later restore is
/// recognised as ours. A restore applies only to a GUID in the baseline: a
/// message the user deleted in the app is never un-hidden by the server. The
/// baseline is only rewritten when it was trusted to begin with; an untrusted
/// baseline is reseeded by the next catch-up pass instead.
({bool apply, Set<String>? nextBaseline}) resolveLiveRecoverableEvent({
  required String guid,
  required bool hide,
  required bool hasTrustedBaseline,
  required Set<String> baselineGuids,
}) {
  if (!hide && !baselineGuids.contains(guid)) return (apply: false, nextBaseline: null);
  if (!hasTrustedBaseline) return (apply: true, nextBaseline: null);
  final next = {...baselineGuids};
  if (hide) {
    next.add(guid);
  } else {
    next.remove(guid);
  }
  return (apply: true, nextBaseline: next);
}

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
  static ({bool trusted, Set<String> guids, int generatedAt}) readBaseline() {
    final raw = PrefsSvc.database.getRecoverableMessageBaseline();
    if (raw == null) return (trusted: false, guids: <String>{}, generatedAt: 0);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('malformed baseline');
      final guids = decoded['guids'];
      if (guids is! List || guids.any((guid) => guid is! String || guid.isEmpty)) {
        throw const FormatException('malformed baseline guid');
      }
      final generatedAt = decoded['generatedAt'];
      return (
        trusted: true,
        guids: guids.cast<String>().toSet(),
        generatedAt: generatedAt is int && generatedAt > 0 ? generatedAt : 0,
      );
    } catch (error, trace) {
      Logger.warn('Recently Deleted baseline was malformed; reseeding',
          error: error, trace: trace, tag: 'RecoverableMessageReconciler');
      return (trusted: false, guids: <String>{}, generatedAt: 0);
    }
  }

  static Future<void> saveBaseline(Set<String> guids, {int generatedAt = 0}) {
    final sorted = guids.toList()..sort();
    return PrefsSvc.database.setRecoverableMessageBaseline(
      jsonEncode({'guids': sorted, 'generatedAt': generatedAt}),
    );
  }

  /// Applies one catch-up hide or restore.
  ///
  /// Prefers MessagesService so an OPEN conversation updates its message struct
  /// and tile exactly as the live events do. That service only exists while the
  /// chat's view is registered, though, and the catch-up runs over every chat —
  /// almost all of them closed. Constructing it here throws
  /// "Only UI owner code should create it", which aborted the whole pass and
  /// left both the hide and the tile repair unapplied.
  ///
  /// So: use the service when it is already there, and otherwise write the
  /// database and correct the chat tile directly.
  /// Applies a live `message-deleted` / `message-restored` event.
  ///
  /// Hides always apply and are recorded in the baseline, so a later restore
  /// is recognised as ours. A restore applies only to a message this client
  /// hid on Apple's behalf; a message the user deleted in the app is never
  /// un-hidden by the server. The catch-up pass enforces the same rule.
  static Future<void> applyLiveEvent(String guid, {required bool hide}) async {
    if (kIsWeb) return;
    final baseline = readBaseline();
    final decision = resolveLiveRecoverableEvent(
      guid: guid,
      hide: hide,
      hasTrustedBaseline: baseline.trusted,
      baselineGuids: baseline.guids,
    );
    if (!decision.apply) {
      Logger.info('Ignoring restore for $guid: not hidden by this client', tag: 'RecoverableMessageReconciler');
      return;
    }
    await _applyThroughService(guid, hide: hide);
    if (decision.nextBaseline != null) {
      await saveBaseline(decision.nextBaseline!, generatedAt: baseline.generatedAt);
    }
  }

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

    final service = maybeFindMessagesSvc(chatGuid);
    if (service != null) {
      if (hide) {
        await service.softDeleteMessage(message);
      } else {
        await service.restoreMessage(message);
      }
      return;
    }

    // No open view. Write the database, then bring the chat tile back in line:
    // it renders from the stored latest-message pointer, not a live query.
    if (hide) {
      await Message.softDelete(guid);
    } else {
      await Message.restore(guid);
    }

    final chat = ChatsSvc.findChatByGuid(chatGuid);
    if (chat == null) return;

    final surviving = Chat.getMessages(chat, limit: 1);
    if (surviving.isEmpty) {
      ChatsSvc.clearChatLatestMessage(chatGuid);
    } else {
      ChatsSvc.updateChatLatestMessage(chatGuid, surviving.first, allowOlder: true);
    }
  }

  /// Corrects chats whose cached latest message is hidden.
  ///
  /// The conversation tile renders from the chat's stored latest-message
  /// pointer rather than a live query, so a pointer left aimed at a hidden
  /// message previews text the thread itself will not show. Hides applied
  /// before this repair existed left exactly that state behind, and it cannot
  /// fix itself: the message is already hidden, so nothing hides it again.
  static Future<void> repairHiddenLatestMessages() async {
    if (kIsWeb) return;

    final query = Database.messages.query(Message_.dateDeleted.notNull()).build();
    final hidden = query.find();
    query.close();
    if (hidden.isEmpty) return;

    final hiddenGuids = hidden.map((message) => message.guid).whereType<String>().toSet();
    var repaired = 0;

    // Repositioning a chat mutates the sorted list, so iterate a copy.
    for (final chat in ChatsSvc.allChats.toList()) {
      final pointer = chat.dbLatestMessage.target;
      final pointerGuid = pointer?.guid;
      if (pointerGuid == null || !hiddenGuids.contains(pointerGuid)) continue;

      final surviving = Chat.getMessages(chat, limit: 1);
      if (surviving.isEmpty) {
        ChatsSvc.clearChatLatestMessage(chat.guid);
      } else {
        ChatsSvc.updateChatLatestMessage(chat.guid, surviving.first, allowOlder: true);
      }
      repaired++;
    }

    if (repaired > 0) {
      Logger.info('Repaired $repaired chat tile(s) previewing a hidden message',
          tag: 'RecoverableMessageReconciler');
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
      final priorBaseline = readBaseline();
      if (isStaleRecoverableSnapshot(snapshotGeneratedAt: snapshot.generatedAt, baselineGeneratedAt: priorBaseline.generatedAt)) {
        // A snapshot older than the one already applied (a delayed response
        // overtaking a newer one) would re-hide messages Apple has since
        // restored, or restore ones it has since deleted. Skip it; the next
        // pass fetches a current one.
        Logger.warn(
          'Refusing to reconcile Recently Deleted: snapshot ${snapshot.generatedAt} is older than applied ${priorBaseline.generatedAt}',
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
      // One unexpected failure must not abandon the rest of the pass, or the
      // baseline save and the tile repair below. A single chat throwing here
      // previously aborted everything.
      var failed = 0;
      for (final guid in actions.toHide) {
        try {
          await _applyThroughService(guid, hide: true);
        } catch (error, trace) {
          failed++;
          Logger.warn('Could not hide $guid', error: error, trace: trace, tag: 'RecoverableMessageReconciler');
        }
      }
      for (final guid in actions.toRestore) {
        try {
          await _applyThroughService(guid, hide: false);
        } catch (error, trace) {
          failed++;
          Logger.warn('Could not restore $guid', error: error, trace: trace, tag: 'RecoverableMessageReconciler');
        }
      }
      if (failed > 0) {
        Logger.warn('$failed Recently Deleted change(s) could not be applied',
            tag: 'RecoverableMessageReconciler');
      }

      // Commit only after every local change succeeded, so a partial failure
      // retries from the previous known-good baseline.
      if (failed == 0) {
        await saveBaseline(actions.nextBaseline, generatedAt: snapshot.generatedAt);
      }

      await repairHiddenLatestMessages();

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
