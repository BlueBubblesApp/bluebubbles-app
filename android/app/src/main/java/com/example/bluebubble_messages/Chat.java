package com.example.bluebubble_messages;


import android.annotation.SuppressLint;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;

import org.json.JSONArray;
import org.json.JSONException;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

class Chat {
    Integer id;
    String guid;
    int style;
    String chatIdentifier;
    boolean isArchived;
    String displayName;
    List<Handle> participants;

    private SQLiteDatabase db;

    public Chat(Context context) {
        DatabaseHelper helper = DatabaseHelper.getInstance(context);
        this.db = helper.getReadableDatabase();
    }

    public static Chat fromMap(Map<String, Object> json, Context context) {
        List<Handle> participants = new ArrayList<Handle>();
        if (json.containsKey("participants")) {
            for (Map<String, Object> participant : (List<Map<String, Object>>) json.get("participants")) {
                participants.add(Handle.fromMap(participant, context));
            }
        }

        Chat chat = new Chat(context);

        // Parse generic fields
        chat.id = (Integer) Utils.parseField(json, "ROWID", "integer");
        chat.guid = (String) Utils.parseField(json, "guid", "string");
        chat.style = (Integer) Utils.parseField(json, "style", "integer");
        chat.chatIdentifier = (String) Utils.parseField(json, "chatIdentifier", "string");
        chat.isArchived = (Boolean) Utils.parseField(json, "isArchived", "boolean");
        chat.displayName = (String) Utils.parseField(json, "displayName", "string");
        chat.participants = participants;

        return chat;
    }

    public static Chat fromCursor(Cursor cursor, Context context) {
        List<Handle> participants = new ArrayList<>();
        if(cursor.getColumnIndex("participants") != -1) {
            try {
                JSONArray _participants = new JSONArray(cursor.getString(cursor.getColumnIndex("participants")));
                for(int i = 0; i < _participants.length(); i++) {
                    participants.add(Handle.fromMap((Map<String, Object>) _participants.get(i), context));
                }
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }
        Chat chat = new Chat(context);
        chat.id = cursor.getInt(cursor.getColumnIndex("ROWID"));
        chat.guid = cursor.getString(cursor.getColumnIndex("guid"));
        chat.style = cursor.getInt(cursor.getColumnIndex("style"));
        chat.chatIdentifier = cursor.getString(cursor.getColumnIndex("chatIdentifier"));
        chat.isArchived = cursor.getInt(cursor.getColumnIndex("isArchived")) == 1 ? true : false;
        chat.displayName = cursor.getString(cursor.getColumnIndex("displayName"));
        chat.participants = participants;

        return chat;


    }

    public static String title(Cursor cursor) {
        String title = "";
//        if (cursor.getString(cursor.getColumnIndex("displayName")) == null || cursor.getString(cursor.getColumnIndex("displayName")) == "") {
//            List<String> titles = [];
//            for (int i = 0; i < chat.participants.length; i++) {
//                titles.add(getContact(
//                        ContactManager().contacts, chat.participants[i].address.toString()));
//            }
//
//            title = titles.join(', ');
//        } else {
//            title = _chat.displayName;
//        }
        return title;
    }

    @SuppressLint("NewApi")
    public Chat save(boolean updateIfAbsent) {
        // Try to find an existing chat before saving it
        Cursor cursor = db.rawQuery("SELECT * FROM chat WHERE guid = ? LIMIT 1", new String[]{this.guid});
        if (cursor.moveToFirst()) {
            this.id = cursor.getInt(cursor.getColumnIndex("ROWID"));
        }

        int count = cursor.getCount();
        cursor.close();

        // If it already exists, update it
        if (count == 0) {
            // Remove the ID from the map for inserting
            ContentValues map = this.toMap();
            if (map.containsKey("ROWID")) {
                map.remove("ROWID");
            }
            if (map.containsKey("participants")) {
                map.remove("participants");
            }

            this.id = Math.toIntExact(db.insert("chat", null, map));
        } else if(updateIfAbsent){
            this.update();
        }

        // Save participants to the chat
        for (int i = 0; i < this.participants.size(); i++) {
            this.addParticipant(this.participants.get(i));
        }

        return this;
    }

    //
    public Chat update() {
        ContentValues params = new ContentValues();
        params.put("isArchived", this.isArchived ? 1 : 0);

        // Add display name if it's been updated
        if (this.displayName != null) {
            if (!params.containsKey("displayName"))
                params.put("displayName", this.displayName);
        }

        // If it already exists, update it
        if (this.id != null) {
            db.update("chat", params, "ROWID = ?", new String[]{String.valueOf(this.id)});
        } else {
            this.save(false);
        }

        return this;
    }

    //
    public Chat addMessage(Message message) {
        // Save the message and the chat
        this.save(true);
        message.save();

        // Check join table and add if relationship doesn't exist
        Cursor entries = db.rawQuery("SELECT * FROM chat_message_join WHERE chatId = ? AND messageId = ?", new String[]{String.valueOf(this.id), String.valueOf(message.id)});
        if (entries.getCount() == 0) {
            ContentValues map = new ContentValues();
            map.put("chatId", this.id);
            map.put("messageId", message.id);
            db.insert("chat_message_join", null, map);
        }

        return this;
    }
//
//    static Future<List<Message>> getMessages(Chat chat,
//    {bool reactionsOnly = false, int offset = 0, int limit = 100}) async {
//        final Database db = await DBProvider.db.database;
//
//        String reactionQualifier = reactionsOnly ? map.put("IS NOT" : map.put("IS";
//        String query = ("SELECT"
//        map.put(" message.ROWID AS ROWID,"
//        map.put(" message.guid AS guid,"
//        map.put(" message.handleId AS handleId,"
//        map.put(" message.text AS text,"
//        map.put(" message.subject AS subject,"
//        map.put(" message.country AS country,"
//        map.put(" message.error AS error,"
//        map.put(" message.dateCreated AS dateCreated,"
//        map.put(" message.dateDelivered AS dateDelivered,"
//        map.put(" message.isFromMe AS isFromMe,"
//        map.put(" message.isDelayed AS isDelayed,"
//        map.put(" message.isAutoReply AS isAutoReply,"
//        map.put(" message.isSystemMessage AS isSystemMessage,"
//        map.put(" message.isForward AS isForward,"
//        map.put(" message.isArchived AS isArchived,"
//        map.put(" message.cacheRoomnames AS cacheRoomnames,"
//        map.put(" message.isAudioMessage AS isAudioMessage,"
//        map.put(" message.datePlayed AS datePlayed,"
//        map.put(" message.itemType AS itemType,"
//        map.put(" message.groupTitle AS groupTitle,"
//        map.put(" message.groupActionType AS groupActionType,"
//        map.put(" message.isExpired AS isExpired,"
//        map.put(" message.associatedMessageGuid AS associatedMessageGuid,"
//        map.put(" message.associatedMessageType AS associatedMessageType,"
//        map.put(" message.expressiveSendStyleId AS texexpressiveSendStyleIdt,"
//        map.put(" message.timeExpressiveSendStyleId AS timeExpressiveSendStyleId,"
//        map.put(" message.hasAttachments AS hasAttachments,"
//        map.put(" handle.ROWID AS handleId,"
//        map.put(" handle.address AS handleAddress,"
//        map.put(" handle.country AS handleCountry,"
//        map.put(" handle.uncanonicalizedId AS handleUncanonicalizedId"
//        map.put(" FROM message"
//        map.put(" JOIN chat_message_join AS cmj ON message.ROWID = cmj.messageId"
//        map.put(" JOIN chat ON cmj.chatId = chat.ROWID"
//        map.put(" LEFT OUTER JOIN handle ON handle.ROWID = message.handleId"
//        map.put(" WHERE chat.ROWID = ? AND message.associatedMessageType $reactionQualifier NULL");
//
//        // Add pagination
//        query += map.put(" ORDER BY message.dateCreated DESC LIMIT $limit OFFSET $offset";
//
//        // Execute the query
//        var res = await db.rawQuery("$query;", [chat.id]);
//
//        // Add the from/handle data to the messages
//        List<Message> output = [];
//        for (int i = 0; i < res.length; i++) {
//            Message msg = Message.fromMap(res[i]);
//
//            // If the handle is not null, load the handle data
//            // The handle is null if the message.handleId is 0
//            // the handleId is 0 when isFromMe is true and the chat is a group chat
//            if (res[i].containsKey('handleAddress') &&
//                    res[i]['handleAddress'] != null) {
//                msg.handle = Handle.fromMap({
//                        'id': res[i]['handleId'],
//                        'address': res[i]['handleAddress'],
//                        'country': res[i]['handleCountry'],
//                        'uncanonicalizedId': res[i]['handleUncanonicalizedId']
//        });
//            }
//
//            output.add(msg);
//        }
//
//        return output;
//    }
//
//    Future<Chat> getParticipants() async {
//        final Database db = await DBProvider.db.database;
//
//        var res = await db.rawQuery(
//                map.put("SELECT"
//                map.put(" handle.ROWID AS ROWID,"
//                map.put(" handle.address AS address,"
//                map.put(" handle.country AS country,"
//                map.put(" handle.uncanonicalizedId AS uncanonicalizedId"
//                map.put(" FROM chat"
//                map.put(" JOIN chat_handle_join AS chj ON chat.ROWID = chj.chatId"
//                map.put(" JOIN handle ON handle.ROWID = chj.handleId"
//                map.put(" WHERE chat.ROWID = ?;",
//                [this.id]);
//
//        this.participants =
//                (res.isNotEmpty) ? res.map((c) => Handle.fromMap(c)).toList() : [];
//        return this;
//    }
//
    public Chat addParticipant(Handle participant) {

        // Save participant and add to list
        participant.save(true);
        if (!this.participants.contains(participant)) {
            this.participants.add(participant);
        }

        // Check join table and add if relationship doesn't exist
        Cursor cursor = db.rawQuery("SELECT * FROM chat_handle_join WHERE chatId = ? AND handleId = ?", new String[]{String.valueOf(this.id), String.valueOf(participant.id)});
        int count = cursor.getCount();
        cursor.close();

        if (count == 0) {
            ContentValues map = new ContentValues();
            map.put("chatId", this.id);
            map.put("handleId", participant.id);
            db.insert("chat_handle_join", null, map);
        }

        return this;
    }
//
//    Future<Chat> removeParticipant(Handle participant) async {
//        final Database db = await DBProvider.db.database;
//
//        // First, remove from the JOIN table
//        await db.delete("chat_handle_join",
//                where: map.put("chatId = ? AND handleId = ?",
//                whereArgs: [this.id, participant.id]);
//
//        // Second, remove from this object instance
//        if (this.participants.contains(participant)) {
//            this.participants.remove(participant);
//        }
//
//        return this;
//    }
//
//    static Future<Chat> findOne(Map<String, dynamic> filters) async {
//        final Database db = await DBProvider.db.database;
//
//        List<String> whereParams = [];
//        filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
//        List<dynamic> whereArgs = [];
//        filters.values.forEach((filter) => whereArgs.add(filter));
//        var res = await db.query("chat",
//                where: whereParams.join(" AND map.put("), whereArgs: whereArgs, limit: 1);
//
//        if (res.isEmpty) {
//            return null;
//        }
//
//        return Chat.fromMap(res.elementAt(0));
//    }
//
//    static Future<List<Chat>> find(
//      [Map<String, dynamic> filters = const {}]) async {
//        final Database db = await DBProvider.db.database;
//
//        List<String> whereParams = [];
//        filters.keys.forEach((filter) => whereParams.add('$filter = ?'));
//        List<dynamic> whereArgs = [];
//        filters.values.forEach((filter) => whereArgs.add(filter));
//
//        var res = await db.query("chat",
//                where: (whereParams.length > 0) ? whereParams.join(" AND map.put(") : null,
//                whereArgs: (whereArgs.length > 0) ? whereArgs : null);
//        return (res.isNotEmpty) ? res.map((c) => Chat.fromMap(c)).toList() : [];
//    }
//
//    static flush() async {
//        final Database db = await DBProvider.db.database;
//        await db.delete("chat");
//    }

    ContentValues toMap() {
        ContentValues map = new ContentValues();
        map.put("ROWID", id);
        map.put("guid", guid);
        map.put("style", style);
        map.put("chatIdentifier", chatIdentifier);
        map.put("isArchived", isArchived ? 1 : 0);
        map.put("displayName", displayName);
        List<Map<String, Object>> newParticipants = new ArrayList<>();
        for (Handle participant : participants) {
            newParticipants.add(participant.toMap());
        }
        map.put("participants", new JSONArray(newParticipants).toString());
        return map;
    }
}
