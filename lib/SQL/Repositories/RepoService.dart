import 'package:bluebubble_messages/SQL/Models/Chats.dart';
import 'package:bluebubble_messages/SQL/Models/Messages.dart';
import 'package:bluebubble_messages/singleton.dart';
import 'package:flutter/material.dart';

import 'DatabaseCreator.dart';

class RepositoryServiceChats {
  static Future<List<Chat>> getAllChats() async {
    final sql =
        '''SELECT * FROM ${DatabaseCreator.chatsTable} ORDER BY lastMessageTimeStamp DESC''';
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

  static Future<int> updateChatTime(
      String guid, int lastMessageTimeStamp) async {
    // final sql =
    //     '''UPDATE ${DatabaseCreator.chatsTable} SET lastMessageTimeStamp = ? WHERE guid = ?''';
    // List params = [
    //   lastMessageTimeStamp,
    //   guid,
    // ];
    Map<String, dynamic> values = new Map();
    values["lastMessageTimeStamp"] = lastMessageTimeStamp;
    final result = await db.update(DatabaseCreator.chatsTable, values,
        where: "guid = ?", whereArgs: [guid]);
    debugPrint("updated $result rows");
    return result;
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

  static Future<int> updateSpecificMessage(int id, String guid) async {
    // final sql =
    //     '''UPDATE ${DatabaseCreator.chatsTable} SET guid = ? WHERE id = ?''';
    // List params = [
    //   id,
    //   dateCreated,
    // ];
    Map<String, dynamic> values = new Map();
    values["guid"] = guid;
    final result = await db.update(DatabaseCreator.chatsTable, values,
        where: "id = ?", whereArgs: [id]);
    debugPrint("updated $result rows");
    return result;
  }

  static Future<void> addEmptyMessageToChat(Message message) async {
    /*
    1. Save to your DB without a guid, when sending
2. Wait for new message from the server
3. On the client, get all texts without a guid
4. Filter that list down by matching on the incoming message text
5. Order that list and match based on which was created first
6. When match is found, replace DB data with data from the server
     */
    final sql = '''INSERT INTO ${DatabaseCreator.messagesTable} 
    (
      guid,
      text,
      chatGuid,
      dateCreated,
      attachments,
      isFromMe 
      ) 
      VALUES (?,?,?,?,?,?)''';
    List<dynamic> params = [
      "NOT-SET",
      message.text,
      message.chatGuid,
      message.dateCreated,
      message.attachments,
      1,
    ];
    final result = await db.rawInsert(sql, params);
    DatabaseCreator.databaseLog('Add message', sql, null, result, params);
  }

  static Future<void> attemptToFixMessage(Message message) async {
    final sql =
        '''SELECT * FROM ${DatabaseCreator.messagesTable} WHERE text = ? AND guid = ? ORDER BY dateCreated DESC''';
    List<dynamic> params = [message.text, "NOT-SET"];
    final results = await db.rawQuery(sql, params);
    if (results != null && results.length > 0) {
      debugPrint("found match: " + results[0].toString());
      // updateSpecificMessage(results[0], message.guid)
    } else {
      debugPrint("could not find message");
      addMessagesToChat([message]);
    }
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
    VALUES (?,?,?,?,?,?)''';
      List<dynamic> params = [
        messages[i].guid,
        messages[i].text,
        messages[i].chatGuid,
        messages[i].dateCreated,
        messages[i].attachments,
        messages[i].isFromMe
      ];
      List existingMessage = await getSpecificMessage(messages[i].guid);
      if (existingMessage != null && existingMessage.length > 0) {
        debugPrint("chat " + messages[i].guid + "already exists");
      } else {
        debugPrint(messages[i].guid);
        final result = await db.rawInsert(sql, params);
        DatabaseCreator.databaseLog('Add message', sql, null, result, params);
      }
      if (i == messages.length - 1) {
        Singleton().notify();
      }
    }
  }
}
