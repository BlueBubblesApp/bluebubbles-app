import 'package:bluebubbles/app/layouts/settings/pages/server/chat_backup_identifier.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/interfaces/custom_group_interface.dart';
import 'package:bluebubbles/services/services.dart';

/// Result of restoring a `customGroups` backup entry list.
class CustomGroupsRestoreResult {
  final List<String> restored;
  final List<String> skipped;

  const CustomGroupsRestoreResult({required this.restored, required this.skipped});
}

/// Exports/imports custom groups in a server/device-agnostic way for the
/// Settings backup/restore feature. Member chats are identified via
/// [ChatBackupIdentifier] rather than `chat.guid`. Group names are unique
/// locally, so on restore a name collision is resolved by suffixing
/// " (1)", " (2)", etc.
class CustomGroupsBackup {
  static Future<List<Map<String, dynamic>>> exportList() async {
    final groups = await CustomGroupInterface.getAll();
    return groups.map((g) {
      return {
        "name": g.name,
        "chats": g.chats.map(ChatBackupIdentifier.export).toList(),
      };
    }).toList();
  }

  static Future<CustomGroupsRestoreResult> restore(List<dynamic> entries) async {
    final restored = <String>[];
    final skipped = <String>[];

    final existingNames = (await CustomGroupInterface.getAll()).map((g) => g.name).toSet();

    for (final entry in List<Map<String, dynamic>>.from(entries)) {
      final baseName = entry["name"] as String;
      final chatEntries = List<Map<String, dynamic>>.from(entry["chats"] as List? ?? []);

      final matchedGuids = <String>[];
      for (final chatEntry in chatEntries) {
        final result = ChatBackupIdentifier.resolve(chatEntry, ChatsSvc.allChats);
        if (result.match != null) {
          matchedGuids.add(result.match!.guid);
        } else {
          final displayName = chatEntry["displayName"] as String?;
          final participants = List<String>.from(chatEntry["participants"] as List? ?? []);
          final label = !isNullOrEmpty(displayName) ? displayName! : participants.join(", ");
          skipped.add("$baseName: $label (${result.skipReason})");
        }
      }

      // Collision handling: suffix " (1)", " (2)", ... against both existing
      // groups and groups already created earlier in this same restore pass.
      var name = baseName;
      var suffix = 1;
      while (existingNames.contains(name)) {
        name = "$baseName ($suffix)";
        suffix++;
      }
      existingNames.add(name);

      await CustomGroupInterface.create(name: name, chatGuids: matchedGuids);
      restored.add(name == baseName ? name : "$baseName (renamed to \"$name\")");
    }

    return CustomGroupsRestoreResult(restored: restored, skipped: skipped);
  }
}
