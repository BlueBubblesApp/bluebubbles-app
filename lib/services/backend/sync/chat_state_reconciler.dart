import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/sync/chat_state_transition.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

final RegExp _decimalPointer = RegExp(r'^(0|[1-9][0-9]*)$');

/// Returns the unread state a trusted snapshot should apply locally.
///
/// The first snapshot only seeds a forward-sync baseline. Once that baseline
/// contains the chat, each newer complete snapshot is Apple-authoritative and
/// repairs local drift even when the persisted baseline itself did not change.
bool? desiredUnreadFromSnapshot({
  required bool hasTrustedBaseline,
  required bool baselineHasChat,
  required bool serverRead,
  required bool localUnread,
}) {
  if (!hasTrustedBaseline || !baselineHasChat) return null;
  final desiredUnread = !serverRead;
  return desiredUnread == localUnread ? null : desiredUnread;
}

class ChatSnapshotEntry {
  const ChatSnapshotEntry({
    required this.guid,
    required this.read,
    required this.messageCount,
    required this.readPointer,
  });

  final String guid;
  final bool read;
  final int messageCount;
  final String readPointer;

  static ChatSnapshotEntry? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final guid = raw['guid'];
    final read = raw['read'];
    final messageCount = raw['messageCount'];
    final readPointer = raw['readPointer'];
    if (guid is! String || guid.isEmpty) return null;
    if (read is! bool) return null;
    if (messageCount is! int || messageCount < 0) return null;
    if (readPointer is! String || !_decimalPointer.hasMatch(readPointer)) return null;
    return ChatSnapshotEntry(guid: guid, read: read, messageCount: messageCount, readPointer: readPointer);
  }

  bool hasSameState(ChatSnapshotEntry other) =>
      read == other.read && messageCount == other.messageCount && readPointer == other.readPointer;
}

class ChatSnapshotOutcome {
  const ChatSnapshotOutcome({
    this.readUpdated = 0,
    this.deleted = 0,
    this.skipped = false,
    this.seeded = false,
    this.reason,
  });

  final int readUpdated;
  final int deleted;
  final bool skipped;
  final bool seeded;
  final String? reason;
}

class _ReadState {
  const _ReadState({required this.readPointer, required this.read});

  final String readPointer;
  final bool read;
}

class _Baseline {
  const _Baseline({
    required this.initialized,
    required this.schemaVersion,
    required this.nonEmptyGuids,
    required this.readStates,
    required this.serverAddress,
    required this.lastGeneratedAt,
  });

  final bool initialized;
  final int schemaVersion;
  final Set<String> nonEmptyGuids;
  final Map<String, _ReadState> readStates;
  final String? serverAddress;
  final int lastGeneratedAt;
}

/// Applies an Apple-authoritative chat snapshot to local state.
///
/// Deletions remain forward-only. Read state is also transition-only: a pointer
/// regression means Mark as Unread; an advance means read only when Apple's
/// unread-row predicate agrees. The pointer's absolute value is never treated
/// as read state. A v2 baseline retains its deletion history and silently seeds
/// v3 read transitions on the first pointer-aware snapshot.
class ChatStateReconciler {
  static Future<void> _applyTail = Future<void>.value();

  static bool _isServerBacked(Chat chat) => chat.guid.isNotEmpty && !chat.guid.startsWith('temp-');

  static _Baseline _emptyBaseline() => const _Baseline(
    initialized: false,
    schemaVersion: 0,
    nonEmptyGuids: {},
    readStates: {},
    serverAddress: null,
    lastGeneratedAt: -1,
  );

  static _Baseline _readBaseline() {
    final raw = PrefsSvc.database.getChatStateBaseline();
    if (raw == null) return _emptyBaseline();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('unsupported baseline');
      final schemaVersion = decoded['schemaVersion'];
      if (schemaVersion != 2 && schemaVersion != 3) throw const FormatException('unsupported baseline');
      if (decoded['nonEmptyGuids'] is! List ||
          decoded['serverAddress'] is! String ||
          decoded['lastGeneratedAt'] is! int) {
        throw const FormatException('malformed baseline');
      }

      final rawGuids = decoded['nonEmptyGuids'] as List;
      if (rawGuids.any((guid) => guid is! String || guid.isEmpty)) {
        throw const FormatException('malformed baseline guid');
      }

      final readStates = <String, _ReadState>{};
      if (schemaVersion == 3) {
        final rawStates = decoded['chatStates'];
        if (rawStates is! Map) throw const FormatException('malformed chat states');
        for (final item in rawStates.entries) {
          final guid = item.key;
          final state = item.value;
          if (guid is! String || guid.isEmpty || state is! Map) {
            throw const FormatException('malformed chat state');
          }
          final pointer = state['readPointer'];
          final read = state['read'];
          if (pointer is! String || !_decimalPointer.hasMatch(pointer) || read is! bool) {
            throw const FormatException('malformed read transition state');
          }
          readStates[guid] = _ReadState(readPointer: pointer, read: read);
        }
      }

      return _Baseline(
        initialized: true,
        schemaVersion: schemaVersion as int,
        nonEmptyGuids: rawGuids.cast<String>().toSet(),
        readStates: readStates,
        serverAddress: decoded['serverAddress'] as String,
        lastGeneratedAt: decoded['lastGeneratedAt'] as int,
      );
    } catch (error, trace) {
      Logger.warn('Chat-state baseline was malformed; reseeding without deletion', error: error, trace: trace);
      return _emptyBaseline();
    }
  }

  static Future<void> _saveBaseline(
    Set<String> nonEmptyGuids,
    Map<String, ChatSnapshotEntry> entries, {
    required String serverAddress,
    required int lastGeneratedAt,
  }) async {
    final sortedGuids = nonEmptyGuids.toList()..sort();
    final sortedEntryGuids = entries.keys.toList()..sort();
    final chatStates = <String, dynamic>{};
    for (final guid in sortedEntryGuids) {
      final entry = entries[guid]!;
      chatStates[guid] = {'readPointer': entry.readPointer, 'read': entry.read};
    }
    await PrefsSvc.database.setChatStateBaseline(
      jsonEncode({
        'schemaVersion': 3,
        'serverAddress': serverAddress,
        'lastGeneratedAt': lastGeneratedAt,
        'nonEmptyGuids': sortedGuids,
        'chatStates': chatStates,
      }),
    );
  }

  static Map<String, Set<String>> _readDeferredDeletionsByServer() {
    final raw = PrefsSvc.database.getDeferredChatDeletions();
    if (raw == null) return {};

    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('malformed deferred deletion map');

    final result = <String, Set<String>>{};
    for (final item in decoded.entries) {
      final serverAddress = item.key;
      final rawGuids = item.value;
      if (serverAddress is! String || serverAddress.isEmpty || rawGuids is! List) {
        throw const FormatException('malformed deferred deletion server');
      }
      if (rawGuids.any((guid) => guid is! String || guid.isEmpty)) {
        throw const FormatException('malformed deferred deletion GUID');
      }
      result[serverAddress] = rawGuids.cast<String>().toSet();
    }
    return result;
  }

  static Set<String> _readDeferredDeletionGuids(String serverAddress) =>
      _readDeferredDeletionsByServer()[serverAddress] ?? <String>{};

  static Future<void> _saveDeferredDeletionGuids(String serverAddress, Set<String> guids) async {
    final byServer = _readDeferredDeletionsByServer();
    if (guids.isEmpty) {
      byServer.remove(serverAddress);
    } else {
      byServer[serverAddress] = {...guids};
    }

    final sortedServers = byServer.keys.toList()..sort();
    final encoded = <String, dynamic>{};
    for (final server in sortedServers) {
      encoded[server] = byServer[server]!.toList()..sort();
    }
    await PrefsSvc.database.setDeferredChatDeletions(jsonEncode(encoded));
  }

  /// Persists a live deletion that cannot yet be applied because local work
  /// would be lost. The next complete snapshot confirms Apple still considers
  /// the chat deleted before retrying it.
  static Future<void> deferDeletion(String guid) {
    final completer = Completer<void>();
    _applyTail = _applyTail.then((_) async {
      try {
        final serverAddress = SettingsSvc.settings.serverAddress.value;
        final guids = _readDeferredDeletionGuids(serverAddress)..add(guid);
        await _saveDeferredDeletionGuids(serverAddress, guids);
        completer.complete();
      } catch (error, trace) {
        completer.completeError(error, trace);
      }
    });
    return completer.future;
  }

  static Future<ChatSnapshotOutcome> apply(Map<String, dynamic> payload) {
    final completer = Completer<ChatSnapshotOutcome>();
    _applyTail = _applyTail.then((_) async {
      try {
        completer.complete(await _apply(payload));
      } catch (error, trace) {
        completer.completeError(error, trace);
      }
    });
    return completer.future;
  }

  static Future<ChatSnapshotOutcome> _apply(Map<String, dynamic> payload) async {
    if (payload['schemaVersion'] != 3) {
      Logger.warn('Unsupported chat snapshot schema; refusing to reconcile');
      return const ChatSnapshotOutcome(skipped: true, reason: 'schema');
    }
    if (payload['complete'] != true) {
      Logger.warn('Chat snapshot was not marked complete; refusing to reconcile');
      return const ChatSnapshotOutcome(skipped: true, reason: 'incomplete');
    }
    final generatedAt = payload['generatedAt'];
    if (generatedAt is! int || generatedAt < 0) {
      Logger.warn('Chat snapshot had no valid generation time; refusing to reconcile');
      return const ChatSnapshotOutcome(skipped: true, reason: 'malformed');
    }

    final rawChats = payload['chats'];
    if (rawChats is! List) {
      Logger.warn('Chat snapshot had no chat list; refusing to reconcile');
      return const ChatSnapshotOutcome(skipped: true, reason: 'malformed');
    }

    final entries = <String, ChatSnapshotEntry>{};
    for (final raw in rawChats) {
      final entry = ChatSnapshotEntry.fromMap(raw);
      if (entry == null) {
        Logger.warn('Chat snapshot contained a malformed row; refusing the entire snapshot');
        return const ChatSnapshotOutcome(skipped: true, reason: 'malformed');
      }
      final existing = entries[entry.guid];
      if (existing != null && !existing.hasSameState(entry)) {
        Logger.warn('Chat snapshot contained conflicting duplicate GUIDs; refusing the entire snapshot');
        return const ChatSnapshotOutcome(skipped: true, reason: 'duplicate');
      }
      entries[entry.guid] = entry;
    }

    final localQuery = Database.chats.query(Chat_.dateDeleted.isNull()).build();
    final localChats = localQuery.find();
    localQuery.close();

    final baseline = _readBaseline();
    final serverAddress = SettingsSvc.settings.serverAddress.value;
    final queuedDeletionGuids = _readDeferredDeletionGuids(serverAddress);
    final confirmedQueuedDeletionGuids = queuedDeletionGuids.where((guid) {
      final entry = entries[guid];
      return entry == null || entry.messageCount == 0;
    }).toSet();
    final baselineMatchesServer = baseline.initialized && baseline.serverAddress == serverAddress;
    if (baselineMatchesServer && generatedAt <= baseline.lastGeneratedAt) {
      Logger.warn('Chat snapshot was older than the applied baseline; refusing to reconcile');
      return const ChatSnapshotOutcome(skipped: true, reason: 'stale');
    }

    final transition = computeChatStateTransition(
      initialized: baselineMatchesServer,
      previouslyNonEmptyGuids: baselineMatchesServer ? baseline.nonEmptyGuids : const {},
      currentMessageCounts: entries.map((guid, entry) => MapEntry(guid, entry.messageCount)),
    );

    var readUpdated = 0;
    var deleted = 0;
    final remainingDeferredDeletionGuids = <String>{};
    final deletionCandidates = {...transition.deletedGuids, ...confirmedQueuedDeletionGuids};

    for (final chat in localChats) {
      if (chat.dateDeleted != null || !_isServerBacked(chat)) continue;
      final entry = entries[chat.guid];

      if (deletionCandidates.contains(chat.guid)) {
        if (ChatsSvc.hasLocalWorkForChat(chat.guid)) {
          remainingDeferredDeletionGuids.add(chat.guid);
          Logger.warn('Deferring server chat deletion because ${chat.guid} has local work', tag: 'ChatStateReconciler');
          continue;
        }
        await ChatsSvc.softDeleteChatLocalOnly(chat);
        deleted++;
        continue;
      }
      if (entry == null) continue;

      final previousReadState = baselineMatchesServer && baseline.schemaVersion == 3
          ? baseline.readStates[chat.guid]
          : null;
      final desiredUnread = desiredUnreadFromSnapshot(
        hasTrustedBaseline: baselineMatchesServer && baseline.schemaVersion == 3,
        baselineHasChat: previousReadState != null,
        serverRead: entry.read,
        localUnread: chat.hasUnreadMessage ?? false,
      );
      if (desiredUnread != null) {
        await ChatsSvc.setChatHasUnreadFromServer(chat, desiredUnread);
        readUpdated++;
      }
    }

    // Commit only after every local effect succeeded. A partial failure retries
    // from the previous known-good state.
    await _saveBaseline(
      {...transition.nextNonEmptyGuids, ...remainingDeferredDeletionGuids},
      entries,
      serverAddress: serverAddress,
      lastGeneratedAt: generatedAt,
    );
    await _saveDeferredDeletionGuids(serverAddress, remainingDeferredDeletionGuids);

    Logger.info(
      'Reconciled chat state: $readUpdated read updates, $deleted forward deletions '
      'against ${entries.length} server chats',
    );

    return ChatSnapshotOutcome(
      readUpdated: readUpdated,
      deleted: deleted,
      seeded: !baselineMatchesServer || baseline.schemaVersion != 3,
    );
  }
}
