// import 'package:async_task/async_task_extension.dart';
// import 'package:bluebubbles/database/database.dart';
// import 'package:bluebubbles/database/models.dart';
// import 'package:bluebubbles/services/services.dart';
// import 'package:bluebubbles/utils/logger/logger.dart';
// import 'package:collection/collection.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// ChatListener cl(String guid) => Get.isRegistered<ChatListener>(tag: guid) ? Get.find<ChatListener>(tag: guid) : throw Exception("Please register and init() ChatsService first!");

// /// Design info: [ChatListener]
// /// Create a single long-lived service for each chat, held unique by its GUID.
// /// This service contains a list of listeners that subscribers can add and
// /// remove themselves from. This class should be the *only* one, apart from the
// /// [ChatsService], that can hold its own instance of a [Chat]. This is
// /// purely to compare the difference between the old and new and inform the
// /// listeners accordingly. All subscribers are expected to know their chat
// /// solely by GUID, and should use the [ChatsService.findOne] method to
// /// get their chat. Do not store any instance of chat in a subscriber class
// /// to avoid data sync issues.
// /// This service also tracks which chat is currently active or not.
// class ChatListener extends GetxService {
//   String guid;
//   Chat? _oldChat;
//   late StreamSubscription<Query<Chat>> listener;
//   final Map<State, List<void Function(List<Symbol>)>> _listeners = {};

//   ChatListener({
//     required this.guid,
//   });

//   @override
//   void onInit() {
//     super.onInit();
//     // ensures _oldChat is a different instance than the one stored in [GlobalChatListener]
//     _oldChat = Chat.findOne(guid: guid);
//     final stream = Database.chats.query(Chat_.guid.equals(guid)).watch();
//     listener = stream.listen((Query<Chat> query) async {
//       final chat = query.findFirst();
//       if (chat == null) {
//         Logger.error("[FATAL] Could not find chat in listener query!", tag: "ChatListener");
//       } else {
//         print("Listener fired");
//         final didDispatch = _dispatchToListeners(chat);
//         // only update the old chat if there was actually a change
//         if (didDispatch) {
//           // ensures _oldChat is a different instance than the one stored in [GlobalChatListener]
//           _oldChat = Chat.findOne(guid: guid);
//         }
//       }
//     });
//   }

//   bool _dispatchToListeners(Chat newChat) {
//     // return true just so that the old chat gets set
//     if (_oldChat == null) return true;
//     final List<Symbol> whatChanged = [];
//     final properties = getObjectBoxModel().model.entities[1].properties;
//     final newChatMap = newChat.toMap();
//     final oldChatMap = _oldChat!.toMap();

//     properties.map((e) => e.name).forEachIndexed((index, s) {
//       bool different = false;
//       if (newChatMap[s] is List) {
//         different = !listEquals(newChatMap[s], oldChatMap[s]);
//       } else {
//         different = newChatMap[s] != oldChatMap[s];
//       }

//       if (different) {
//         Logger.info("Got update for chat ${newChat.guid} {$s} - OLD [${oldChatMap[s]}] | NEW [${newChatMap[s]}]", tag: "ChatListener");
//         whatChanged.add(Symbol(s));
//       }
//     });

//     if (whatChanged.isNotEmpty) {
//       // update the chat and force the service to sort only if the chat has been soft deleted
//       chatsService.updateChat(newChat, shouldSort: whatChanged.any({#dateDeleted, #isPinned, #pinIndex}.contains));
//       for (var element in _listeners.values.flattened) {
//         element.call(whatChanged);
//       }
//       return true;
//     } else {
//       return false;
//     }
//   }

//   void addListener(State widget, void Function(List<Symbol>) listener) {
//     if (_listeners.containsKey(widget)) {
//       _listeners[widget]!.add(listener);
//     } else {
//       _listeners[widget] = [listener];
//     }
//   }

//   void removeListeners(State widget) {
//     _listeners[widget]?.clear();
//   }

//   @override
//   void onClose() {
//     listener.cancel();
//     super.onClose();
//   }
// }