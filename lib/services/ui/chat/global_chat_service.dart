import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:get/get.dart';

// ignore: library_private_types_in_public_api, non_constant_identifier_names
_GlobalChatService GlobalChatService = Get.isRegistered<_GlobalChatService>() ? Get.find<_GlobalChatService>() : Get.put(_GlobalChatService());

class _GlobalChatService extends GetxService {
  final RxInt _unreadCount = 0.obs;
  final Map<String, RxBool> _unreadCountMap = <String, RxBool>{}.obs;
  final Map<String, RxnString> _muteTypeMap = <String, RxnString>{}.obs;

  RxInt get unreadCount => _unreadCount;

  RxBool unreadState(String chatGuid) {
    final map = _unreadCountMap[chatGuid];
    if (map == null) {
      _unreadCountMap[chatGuid] = false.obs;
      return _unreadCountMap[chatGuid]!;
    }

    return map;
  }

  RxnString muteState(String chatGuid) {
    final map = _muteTypeMap[chatGuid];
    if (map == null) {
      _muteTypeMap[chatGuid] = RxnString();
      return _muteTypeMap[chatGuid]!;
    }

    return map;
  }

  @override
  void onInit() {
    super.onInit();
    watchChats();
  }

  void watchChats() {
    final query = Database.chats.query().watch(triggerImmediately: true);
    query.listen((event) {
      final chats = event.find();

      // Detect changes and make updates
      _evaluateUnreadInfo(chats);
      _evaluateMuteInfo(chats);
    });
  }

  void _evaluateUnreadInfo(List<Chat> chats) {
    unreadCount.value = chats.where((element) => element.hasUnreadMessage ?? false).length;

    for (Chat chat in chats) {
      final RxBool? currentUnreadStatus = _unreadCountMap[chat.guid];
      
      // Set the default value
      if (currentUnreadStatus == null) {
        _unreadCountMap[chat.guid] = RxBool(false);
        _unreadCountMap[chat.guid]!.value = chat.hasUnreadMessage ?? false;
      } else if (currentUnreadStatus.value != chat.hasUnreadMessage) {
        Logger.debug("Updating Chat (${chat.guid}) Unread Status from ${currentUnreadStatus.value} to ${chat.hasUnreadMessage}");
        _unreadCountMap[chat.guid]!.value = chat.hasUnreadMessage ?? false;
      }
    }
  }

  void _evaluateMuteInfo(List<Chat> chats) {
    for (Chat chat in chats) {
      final Rx<String?>? currentMuteStatus = _muteTypeMap[chat.guid];

      // Set the default value
      if (currentMuteStatus == null) {
        _muteTypeMap[chat.guid] = RxnString();
        _muteTypeMap[chat.guid]!.value = chat.muteType;
      } else if (currentMuteStatus.value != chat.muteType) {
        Logger.debug("Updating Chat (${chat.guid}) Mute Type from ${currentMuteStatus.value} to ${chat.muteType}");
        _muteTypeMap[chat.guid]!.value = chat.muteType;
      }
    }
  }
}