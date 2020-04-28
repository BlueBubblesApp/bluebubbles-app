import 'package:bluebubble_messages/SQL/Models/Chats.dart';
import 'package:bluebubble_messages/SQL/Models/Messages.dart';
import 'package:flutter/material.dart';

import 'DatabaseCreator.dart';

class RepositoryServiceChats {
  static Future<List<Chat>> getAllChats() async {
    final sql = '''SELECT * FROM ${DatabaseCreator.chatsTable}''';
    final data = await db.rawQuery(sql);
    List<Chat> todos = List();

    for (final node in data) {
      final todo = Chat.fromJson(node);
      todos.add(todo);
    }
    return todos;
  }

  static Future<List<Map<String, dynamic>>> getChat(String guid) async {
    //final sql = '''SELECT * FROM ${DatabaseCreator.todoTable}
    //WHERE ${DatabaseCreator.id} = $id''';
    //final data = await db.rawQuery(sql);

    final sql = '''SELECT * FROM ${DatabaseCreator.chatsTable}
    WHERE guid = ? ''';

    List<dynamic> params = [guid];
    final data = await db.rawQuery(sql, params);

    // final todo = Chat.fromJson(data.first);
    return data;
  }

  static Future<void> addChat(Chat chat) async {
    /*final sql = '''INSERT INTO ${DatabaseCreator.todoTable}
    (
      ${DatabaseCreator.id},
      ${DatabaseCreator.name},
      ${DatabaseCreator.info},
      ${DatabaseCreator.isDeleted}
    )
    VALUES 
    (
      ${todo.id},
      "${todo.name}",
      "${todo.info}",
      ${todo.isDeleted ? 1 : 0}
    )''';*/

    final sql = '''INSERT INTO ${DatabaseCreator.chatsTable}
    (
      guid,
      title,
      lastMessageTimeStamp,
      chatIdentifier
      
    )
    VALUES (?,?,?,?)''';
    List<dynamic> params = [
      chat.guid,
      chat.title,
      chat.lastMessageTimeStamp,
      chat.chatIdentifier
    ];
    List existingChats = await getChat(chat.guid);
    if (existingChats.length > 0) {
      debugPrint("chat " + chat.guid + "already exists");
      return;
    }

    final result = await db.rawInsert(sql, params);
    DatabaseCreator.databaseLog('Add chat', sql, null, result, params);
  }

  // static Future<void> deleteChat(Chat chat) async {
  //   /*final sql = '''UPDATE ${DatabaseCreator.todoTable}
  //   SET ${DatabaseCreator.isDeleted} = 1
  //   WHERE ${DatabaseCreator.id} = ${todo.id}
  //   ''';*/

  //   final sql = '''UPDATE ${DatabaseCreator.chatsTable}
  //   SET ${DatabaseCreator.isDeleted} = 1
  //   WHERE ${DatabaseCreator.id} = ?
  //   ''';

  //   List<dynamic> params = [todo.id];
  //   final result = await db.rawUpdate(sql, params);

  //   DatabaseCreator.databaseLog('Delete todo', sql, null, result, params);
  // }

  // static Future<void> updateTodo(Chat todo) async {
  //   /*final sql = '''UPDATE ${DatabaseCreator.todoTable}
  //   SET ${DatabaseCreator.name} = "${todo.name}"
  //   WHERE ${DatabaseCreator.id} = ${todo.id}
  //   ''';*/

  //   final sql = '''UPDATE ${DatabaseCreator.chatsTable}
  //   SET ${DatabaseCreator.name} = ?
  //   WHERE guid = ?
  //   ''';

  //   List<dynamic> params = [todo.name, todo.guid];
  //   final result = await db.rawUpdate(sql, params);

  //   DatabaseCreator.databaseLog('Update todo', sql, null, result, params);
  // }

  // static Future<int> todosCount() async {
  //   final data = await db
  //       .rawQuery('''SELECT COUNT(*) FROM ${DatabaseCreator.chatsTable}''');

  //   int count = data[0].values.elementAt(0);
  //   int idForNewItem = count++;
  //   return idForNewItem;
  // }
}

class RepositoryServiceMessage {
  static Future<List<Message>> getMessagesFromChat(String chatGuid) async {
    var sql = '''SELECT * FROM ${DatabaseCreator.messagesTable}
    WHERE chatGuid = ? ORDER BY dateCreated DESC''';

    List<dynamic> params = [chatGuid];
    final data = await db.rawQuery(sql, params);
    List<Message> messages = List();

    for (final node in data) {
      final message = Message.fromJson(node);
      messages.add(message);
    }
    return messages;
  }

  static Future<List<Map<String, dynamic>>> getSpecificMessage(
      String guid) async {
    final sql =
        '''SELECT * FROM ${DatabaseCreator.messagesTable} WHERE guid = ?''';
    List<dynamic> params = [guid];
    final data = await db.rawQuery(sql, params);
    return data;
  }

  static Future<void> addMessagesToChat(List<Message> messages) async {
    for (int i = 0; i < messages.length; i++) {
      final sql = '''INSERT INTO ${DatabaseCreator.messagesTable}
    (
      guid,
      text,
      chatGuid,
      dateCreated,
      attachments,
      isFromMe
    )
    VALUES (?,?,?,?,?,?) ORDER BY dateCreated ''';
      List<dynamic> params = [
        messages[i].guid,
        messages[i].text,
        messages[i].chatGuid,
        messages[i].dateCreated,
        messages[i].attachments,
        messages[i].isFromMe
      ];
      List existingMessage = await getSpecificMessage(messages[i].guid);
      if (existingMessage != null && existingMessage.length > 1) {
        debugPrint("chat " + messages[i].guid + "already exists");
        return;
      }

      final result = await db.rawInsert(sql, params);
      DatabaseCreator.databaseLog('Add message', sql, null, result, params);
    }
  }
}
