import 'package:bluebubbles/app/layouts/chat_creator/chat_creator_utils.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';

/// Result of restoring a `pinnedChats` backup entry list.
class PinnedChatsRestoreResult {
  final List<String> restored;
  final List<String> skipped;

  const PinnedChatsRestoreResult({required this.restored, required this.skipped});
}

/// Exports/imports pinned chats in a server/device-agnostic way for the
/// Settings backup/restore feature. Chat `guid`s are server-specific, so
/// chats are identified on import by (in priority order): named-group
/// displayName, DM participant address, or full participant address set.
class PinnedChatsBackup {
  static List<Map<String, dynamic>> exportList() {
    // Deliberately not exporting chat.guid: it's assigned by the server, so
    // the same logical conversation gets a different guid on a different
    // server (or after a server reinstall). displayName/participant
    // addresses are the only chat attributes that stay stable across
    // servers, so they're what we match against on import instead.
    return ChatsSvc.pinnedChats.map((chat) {
      final addresses = chat.handles.map((h) => h.address).toList();
      final String type;
      if (!isNullOrEmpty(chat.displayName)) {
        type = "namedGroup";
      } else if (chat.handles.length == 1) {
        type = "dm";
      } else {
        type = "group";
      }

      return {
        "type": type,
        "displayName": chat.displayName,
        "participants": addresses,
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
      final type = entry["type"] as String?;
      final displayName = entry["displayName"] as String?;
      final participants = List<String>.from(entry["participants"] as List? ?? []);
      final label = !isNullOrEmpty(displayName) ? displayName! : participants.join(", ");

      Chat? match;
      String? skipReason;

      switch (type) {
        case "namedGroup":
          final candidates = ChatsSvc.allChats.where((c) => c.isGroup && c.displayName == displayName).toList();
          if (candidates.length == 1) {
            match = candidates.first;
          } else {
            skipReason = candidates.isEmpty ? "no matching group found" : "ambiguous: ${candidates.length} groups named \"$displayName\"";
          }
          break;
        case "dm":
          if (participants.isEmpty) {
            skipReason = "no participant address in backup";
            break;
          }
          final address = participants.first;
          final candidates = ChatsSvc.allChats
              .where((c) => c.handles.length == 1 && ChatCreatorUtils.addressesMatch(address, c.handles.first.address))
              .toList();
          if (candidates.length == 1) {
            match = candidates.first;
          } else {
            skipReason = candidates.isEmpty ? "no matching chat found" : "ambiguous: ${candidates.length} chats match";
          }
          break;
        case "group":
          final candidates = ChatsSvc.allChats
              .where((c) => c.isGroup && isNullOrEmpty(c.displayName) && ChatCreatorUtils.chatMatchesSelectedContacts(c, participants))
              .toList();
          if (candidates.length == 1) {
            match = candidates.first;
          } else {
            skipReason = candidates.isEmpty ? "no matching group found" : "ambiguous: ${candidates.length} groups match";
          }
          break;
        default:
          skipReason = "unknown entry type";
      }

      if (match != null) {
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
        skipped.add("$label ($skipReason)");
      }
    }

    return PinnedChatsRestoreResult(restored: restored, skipped: skipped);
  }
}
