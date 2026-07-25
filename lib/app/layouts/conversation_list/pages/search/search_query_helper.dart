import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:objectbox/src/native/query/query.dart' as obx;

import 'search_models.dart';

class SearchQueryHelper {
  static Future<List<SearchResultItem>> runLocal({
    required String term,
    required Chat? selectedChat,
    required Handle? selectedHandle,
    required bool isFromMe,
    required bool isNotFromMe,
    required DateTime? sinceDate,
  }) async {
    obx.Condition<Message> condition = Message_.text
        .contains(term, caseSensitive: false)
        .and(Message_.associatedMessageGuid.isNull())
        .and(Message_.dateDeleted.isNull())
        .and(Message_.dateCreated.notNull());

    if (isFromMe) {
      condition = condition.and(Message_.isFromMe.equals(true));
    } else if (isNotFromMe) {
      condition = condition.and(Message_.isFromMe.equals(false));
    } else if (selectedHandle != null) {
      condition = condition.and(Message_.handleId.equals(selectedHandle.originalROWID!));
    }

    if (sinceDate != null) {
      condition = condition.and(Message_.dateCreated.greaterOrEqual(sinceDate.millisecondsSinceEpoch));
    }

    QueryBuilder<Message> qBuilder = Database.messages.query(condition);
    if (selectedChat != null) {
      qBuilder = qBuilder..link(Message_.chat, Chat_.guid.equals(selectedChat.guid));
    }

    final query = qBuilder.order(Message_.dateCreated, flags: Order.descending).build();
    query.limit = 50;
    final results = query.find();
    query.close();

    final messages = results.map((e) {
      e.realAttachments;
      e.fetchAssociatedMessages();
      return e;
    }).toList();
    final chats = results.map((e) => e.chat.target).toList();

    final items = <SearchResultItem>[];
    chats.forEachIndexed((index, chat) {
      if (chat == null) return;
      items.add(SearchResultItem(chat: chat, message: messages[index]));
    });
    return items;
  }

  static Future<List<SearchResultItem>> runNetwork({
    required String term,
    required Chat? selectedChat,
    required Handle? selectedHandle,
    required bool isFromMe,
    required bool isNotFromMe,
    required DateTime? sinceDate,
  }) async {
    final whereClause = <Map<String, dynamic>>[
      {
        'statement': 'message.text LIKE :term COLLATE NOCASE',
        'args': {'term': "%$term%"}
      },
      {'statement': 'message.associated_message_guid IS NULL', 'args': null}
    ];

    if (selectedChat != null) {
      whereClause.add({
        'statement': 'chat.guid = :guid',
        'args': {'guid': selectedChat.guid}
      });
    }

    if (isFromMe) {
      whereClause.add({
        'statement': 'message.is_from_me = :isFromMe',
        'args': {'isFromMe': 1}
      });
    } else if (isNotFromMe) {
      whereClause.add({
        'statement': 'message.is_from_me = :isFromMe',
        'args': {'isFromMe': 0}
      });
    } else if (selectedHandle != null) {
      whereClause.add({
        'statement': 'handle.id = :addr',
        'args': {'addr': selectedHandle.address}
      });
    }

    final results = await MessagesService.getMessages(
      limit: 50,
      after: sinceDate?.millisecondsSinceEpoch,
      withChats: true,
      withHandles: true,
      withAttachments: true,
      withChatParticipants: true,
      where: whereClause,
    );

    final itemChats = <Chat>[];
    final itemMessages = <Message>[];
    for (final item in results) {
      itemChats.add(Chat.fromMap(item['chats'][0]));
      itemMessages.add(Message.fromMap(item));
    }

    final chatGuids = itemChats.map((e) => e.guid).toList();
    final dbChatQuery = Database.chats.query(Chat_.guid.oneOf(chatGuids)).build();
    final List<Chat> dbChats;
    try {
      dbChats = dbChatQuery.find();
    } finally {
      dbChatQuery.close();
    }

    // Indexed by guid so each result is a hash lookup, not a scan.
    final dbChatsByGuid = {for (final c in dbChats) c.guid: c};

    final items = <SearchResultItem>[];
    for (int i = 0; i < itemChats.length; i++) {
      final chat = dbChatsByGuid[itemChats[i].guid] ?? itemChats[i];
      items.add(SearchResultItem(chat: chat, message: itemMessages[i]));
    }
    return items;
  }
}
