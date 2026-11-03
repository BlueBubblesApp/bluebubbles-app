import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend/interfaces/message_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';

/// One-time repair for messages that lost their chat link.
///
/// From 2.1.3 until `MessageActions.saveMessageAsync` was fixed, saving a link's preview
/// metadata wrote the message back with no chat, so the link vanished from its
/// conversation. The rows themselves are intact: this asks the server which chat each
/// chatless message belongs to and links it back.
abstract final class ChatlessMessageRepair {
  static const String _tag = 'ChatlessMessageRepair';

  static Future<void> run() async {
    if (PrefsSvc.database.getChatlessMessageRepairDone()) return;

    final guids = await MessageInterface.findChatlessMessageGuids();
    final chatGuids = <String, String>{};
    for (final guid in guids) {
      try {
        final response = await HttpSvc.message.fetchOne(guid, withQuery: "chats");
        final chats = (response.data['data']?['chats'] as List?) ?? const [];
        final chatGuid = chats.whereType<Map>().firstOrNull?['guid'] as String?;
        if (chatGuid != null) chatGuids[guid] = chatGuid;
      } catch (e, s) {
        // A request that never reached the server means we're offline: stop and retry next
        // launch. Anything else (e.g. the message was deleted on the Mac) only skips this one.
        if (e is DioException && httpStatusCodeOf(e) == null) {
          Logger.warn('Server unreachable, retrying next launch', error: e, trace: s, tag: _tag);
          return;
        }
        Logger.warn('Could not look up chat for message $guid', error: e, trace: s, tag: _tag);
      }
    }

    final relinked = chatGuids.isEmpty ? 0 : await MessageInterface.relinkMessagesToChats(chatGuids: chatGuids);
    Logger.info('Relinked $relinked of ${guids.length} chatless messages', tag: _tag);
    await PrefsSvc.database.setChatlessMessageRepairDone();
  }
}
