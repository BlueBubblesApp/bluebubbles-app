import 'package:bluebubbles/app/layouts/settings/pages/server/chat_backup_identifier.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';

/// Result of restoring a `pinnedChats` backup entry list.
class PinnedChatsRestoreResult {
  final List<String> restored;
  final List<String> skipped;

  const PinnedChatsRestoreResult({required this.restored, required this.skipped});
}

/// Exports/imports pinned chats in a server/device-agnostic way for the
/// Settings backup/restore feature. Chats are identified via
/// [ChatBackupIdentifier] (displayName/participant addresses) rather than
/// `chat.guid`, since guids are server-assigned and don't stay stable across
/// servers/reinstalls.
class PinnedChatsBackup {
  static List<Map<String, dynamic>> exportList() {
    return ChatsSvc.pinnedChats.map((chat) {
      return {
        ...ChatBackupIdentifier.export(chat),
        "pinIndex": chat.pinIndex,
      };
    }).toList();
  }

  static Future<PinnedChatsRestoreResult> restore(List<dynamic> entries) async {
    final restored = <String>[];
    final skipped = <String>[];

    final currentMaxPinIndex =
        ChatsSvc.pinnedChats.fold<int>(-1, (max, c) => (c.pinIndex ?? -1) > max ? (c.pinIndex ?? -1) : max);
    var nextPinIndex = currentMaxPinIndex + 1;

    final sortedEntries = List<Map<String, dynamic>>.from(entries)
      ..sort((a, b) => ((a["pinIndex"] as int?) ?? 0).compareTo((b["pinIndex"] as int?) ?? 0));

    for (final entry in sortedEntries) {
      final displayName = entry["displayName"] as String?;
      final participants = List<String>.from(entry["participants"] as List? ?? []);
      final label = !isNullOrEmpty(displayName) ? displayName! : participants.join(", ");

      final result = ChatBackupIdentifier.resolve(entry, ChatsSvc.allChats);

      if (result.match != null) {
        final match = result.match!;
        // Leave the pin order of chats that are already pinned untouched so
        // re-importing the same backup doesn't reshuffle existing pins.
        final alreadyPinned = match.isPinned ?? false;
        await ChatsSvc.setChatPinned(match, true);
        if (!alreadyPinned) {
          await ChatsSvc.setChatPinIndex(match, nextPinIndex);
          nextPinIndex++;
        }
        restored.add(label);
      } else {
        skipped.add("$label (${result.skipReason})");
      }
    }

    return PinnedChatsRestoreResult(restored: restored, skipped: skipped);
  }
}
