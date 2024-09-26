import 'dart:async';

import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:tuple/tuple.dart';

ChatManager cm = Get.isRegistered<ChatManager>() ? Get.find<ChatManager>() : Get.put(ChatManager());

class ChatManager extends GetxService {
  /// Fetch chat information from the server
  Future<Chat?> fetchChat(String chatGuid, {withParticipants = true, withLastMessage = false}) async {
    Logger.info("Fetching full chat metadata from server.", tag: "Fetch-Chat");

    final withQuery = <String>[];
    if (withParticipants) withQuery.add("participants");
    if (withLastMessage) withQuery.add("lastmessage");

    final response = await http.singleChat(chatGuid, withQuery: withQuery.join(",")).catchError((err, stack) {
      if (err is! Response) {
        Logger.error("Failed to fetch chat metadata!", error: err, trace: stack, tag: "Fetch-Chat");
        return err;
      }
      return Response(requestOptions: RequestOptions(path: ''));
    });

    if (response.statusCode == 200 && response.data["data"] != null) {
      Map<String, dynamic> chatData = response.data["data"];

      Logger.info("Got updated chat metadata from server. Saving.", tag: "Fetch-Chat");
      Chat updatedChat = Chat.fromMap(chatData);
      Chat? chat = Chat.findOne(guid: chatGuid);
      if (chat == null) {
        updatedChat.save();
        chat = Chat.findOne(guid: chatGuid)!;
      } else if (chat.handles.length > updatedChat.participants.length) {
        final newAddresses = updatedChat.participants.map((e) => e.address);
        final handlesToUse = chat.participants.where((e) => newAddresses.contains(e.address));
        chat.handles.clear();
        chat.handles.addAll(handlesToUse);
        chat.handles.applyToDb();
      } else if (chat.handles.length < updatedChat.participants.length) {
        final existingAddresses = chat.participants.map((e) => e.address);
        final newHandle = updatedChat.participants.firstWhere((e) => !existingAddresses.contains(e.address));
        final handle = Handle.findOne(addressAndService: Tuple2(newHandle.address, chat.isIMessage ? "iMessage" : "SMS")) ?? newHandle.save();
        chat.handles.add(handle);
        chat.handles.applyToDb();
      }
      if (!chat.lockChatName) {
        chat.displayName = updatedChat.displayName;
      }
      chat = chat.save(updateDisplayName: !chat.lockChatName);
      return chat;
    }

    return null;
  }

  Future<List<Chat>> getChats({bool withParticipants = false, bool withLastMessage = false, int offset = 0, int limit = 100,}) async {
    final withQuery = <String>[];
    if (withParticipants) withQuery.add("participants");
    if (withLastMessage) withQuery.add("lastmessage");

    final response = await http.chats(withQuery: withQuery, offset: offset, limit: limit, sort: withLastMessage ? "lastmessage" : null).catchError((err, stack) {
      if (err is! Response) {
        Logger.error("Failed to fetch chat metadata!", error: err, trace: stack, tag: "Fetch-Chat");
        return err;
      }
      return Response(requestOptions: RequestOptions(path: ''));
    });

    // parse chats from the response
    final chats = <Chat>[];
    for (var item in response.data["data"]) {
      try {
        var chat = Chat.fromMap(item);
        chats.add(chat);
      } catch (ex) {
        chats.add(Chat(guid: "ERROR", displayName: item.toString()));
      }
    }

    return chats;
  }

  Future<List<dynamic>> getMessages(String guid, {bool withAttachment = true, bool withHandle = true, int offset = 0, int limit = 25, String sort = "DESC", int? after, int? before}) async {
    Completer<List<dynamic>> completer = Completer();
    final withQuery = <String>["message.attributedBody", "message.messageSummaryInfo", "message.payloadData"];
    if (withAttachment) withQuery.add("attachment");
    if (withHandle) withQuery.add("handle");

    http.chatMessages(guid, withQuery: withQuery.join(","), offset: offset, limit: limit, sort: sort, after: after, before: before).then((response) {
      if (!completer.isCompleted) completer.complete(response.data["data"]);
    }).catchError((err) {
      late final dynamic error;
      if (err is Response) {
        error = err.data["error"]["message"];
      } else {
        error = err.toString();
      }
      if (!completer.isCompleted) completer.completeError(error);
    });

    return completer.future;
  }
}
