import 'package:bluebubble_messages/SQL/Models/Chats.dart';

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

  static Future<Chat> getChat(String guid) async {
    //final sql = '''SELECT * FROM ${DatabaseCreator.todoTable}
    //WHERE ${DatabaseCreator.id} = $id''';
    //final data = await db.rawQuery(sql);

    final sql = '''SELECT * FROM ${DatabaseCreator.chatsTable}
    WHERE guid = ?''';

    List<dynamic> params = [guid];
    final data = await db.rawQuery(sql, params);

    final todo = Chat.fromJson(data.first);
    return todo;
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
      chatIdentifier,
      
    )
    VALUES (?,?,?,?,?)''';
    List<dynamic> params = [
      chat.guid,
      chat.title,
      chat.lastMessageTimeStamp,
      chat.chatIdentifier
    ];
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
