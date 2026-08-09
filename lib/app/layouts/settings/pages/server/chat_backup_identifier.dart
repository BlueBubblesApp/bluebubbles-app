import 'package:bluebubbles/app/layouts/chat_creator/chat_creator_utils.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';

/// Result of resolving a backup chat entry against a local chat pool.
class ChatBackupMatch {
  final Chat? match;
  final String? skipReason;

  const ChatBackupMatch({this.match, this.skipReason});
}

/// Shared server/device-agnostic chat identification for Settings backup/restore
/// features (Pinned Chats, Custom Groups). Chat `guid`s are server-specific, so
/// chats are identified by (in priority order): named-group displayName, DM
/// participant address, or full participant address set.
class ChatBackupIdentifier {
  static Map<String, dynamic> export(Chat chat) {
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
    };
  }

  static ChatBackupMatch resolve(Map<String, dynamic> entry, List<Chat> pool) {
    final type = entry["type"] as String?;
    final displayName = entry["displayName"] as String?;
    final participants = List<String>.from(entry["participants"] as List? ?? []);

    switch (type) {
      case "namedGroup":
        final candidates = pool.where((c) => c.isGroup && c.displayName == displayName).toList();
        if (candidates.length == 1) {
          return ChatBackupMatch(match: candidates.first);
        }
        return ChatBackupMatch(
            skipReason:
                candidates.isEmpty ? "no matching group found" : "ambiguous: ${candidates.length} groups named \"$displayName\"");
      case "dm":
        if (participants.isEmpty) {
          return const ChatBackupMatch(skipReason: "no participant address in backup");
        }
        final address = participants.first;
        final candidates = pool
            .where((c) => c.handles.length == 1 && ChatCreatorUtils.addressesMatch(address, c.handles.first.address))
            .toList();
        if (candidates.length == 1) {
          return ChatBackupMatch(match: candidates.first);
        }
        return ChatBackupMatch(
            skipReason: candidates.isEmpty ? "no matching chat found" : "ambiguous: ${candidates.length} chats match");
      case "group":
        final candidates = pool
            .where((c) =>
                c.isGroup && isNullOrEmpty(c.displayName) && ChatCreatorUtils.chatMatchesSelectedContacts(c, participants))
            .toList();
        if (candidates.length == 1) {
          return ChatBackupMatch(match: candidates.first);
        }
        return ChatBackupMatch(
            skipReason: candidates.isEmpty ? "no matching group found" : "ambiguous: ${candidates.length} groups match");
      default:
        return const ChatBackupMatch(skipReason: "unknown entry type");
    }
  }
}
