import 'dart:async';

import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';

Map<String, Completer<Chat>> chatCache = {};

/// A wrapper for the `SocketManager().fetchChat()` function that only allows one instance
/// of a fetch, per chat by [chatGuid]. This was created so that stream listeners from
/// multiple widgets can request the `fetchChat()` function, at the same time, without actually
/// sending multiple requests to the server. Each call within 5 seconds will piggy-back on the previous
Future<Chat?> fetchChatSingleton(String chatGuid, {withParticipants = true}) async {
  // If we are already processing, return the currently processed item
  if (chatCache.containsKey(chatGuid)) return chatCache[chatGuid]?.future;
  chatCache[chatGuid] = Completer<Chat>();

  // A local helper function for removing from the cache
  void removeFromCache(String guid) {
    if (chatCache.containsKey(guid)) {
      chatCache.remove(guid);
    }
  }

  // Fetch the chat data
  SocketManager().fetchChat(chatGuid, withParticipants: withParticipants).then((Chat? chat) {
    // If the chat GUID isn't in the cache anymore, return
    if (!chatCache.containsKey(chatGuid)) return;
    chatCache[chatGuid]?.complete(chat);

    // Remove the item from the cache after 5 seconds
    Future.delayed(const Duration(seconds: 5)).then((_) {
      removeFromCache(chatGuid);
    });
  }).catchError((e) {
    // If there is an error, forward the error to the completer
    chatCache[chatGuid]?.completeError(e);

    // Remove it from the cache
    removeFromCache(chatGuid);
  });

  return chatCache[chatGuid]?.future;
}
