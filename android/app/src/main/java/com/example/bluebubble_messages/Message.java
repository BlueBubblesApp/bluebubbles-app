package com.example.bluebubble_messages;

import android.annotation.SuppressLint;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.health.TimerStat;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

class Message {
    Integer id;
    String guid;
    Integer handleId;
    String text;
    String subject;
    String country;
    boolean error;
    Timestamp dateCreated;
    Timestamp dateRead;
    Timestamp dateDelivered;
    boolean isFromMe;
    boolean isDelayed;
    boolean isAutoReply;
    boolean isSystemMessage;
    boolean isServiceMessage;
    boolean isForward;
    boolean isArchived;
    String cacheRoomnames;
    boolean isAudioMessage;
    Date datePlayed;
    Integer itemType;
    String groupTitle;
    Integer groupActionType;
    boolean isExpired;
    String associatedMessageGuid;
    String associatedMessageType;
    String expressiveSendStyleId;
    Date timeExpressiveSendStyleId;
    Handle handle;
    boolean hasAttachments;

    private SQLiteDatabase db;

    public Message(Context context) {
        DatabaseHelper helper = DatabaseHelper.getInstance(context);
        this.db = helper.getWritableDatabase();
    }

    public static Message fromMap(Map<String, Object> json, Context context) {
        Message message = new Message(context);

        // Parse some of the generic fields
        message.id = (Integer) Utils.parseField(json, "ROWID", "integer");
        message.guid = (String) Utils.parseField(json, "guid", "string");
        message.handleId = (Integer) Utils.parseField(json, "handleId", "integer");
        message.text = (String) Utils.parseField(json, "text", "string");
        message.subject = (String) Utils.parseField(json, "subject", "string");
        message.country = (String) Utils.parseField(json, "country", "string");
        message.error = (Boolean) Utils.parseField(json, "error", "boolean");
        message.dateCreated = (Timestamp) Utils.parseField(json, "dateCreated", "timestamp");
        message.dateRead = (Timestamp) Utils.parseField(json, "dateRead", "timestamp");
        message.dateDelivered = (Timestamp) Utils.parseField(json, "dateDelivered", "timestamp");
        message.isFromMe = (Boolean) Utils.parseField(json, "isFromMe", "boolean");
        message.isDelayed = (Boolean) Utils.parseField(json, "isDelayed", "boolean");
        message.isAutoReply = (Boolean) Utils.parseField(json, "isAutoReply", "boolean");
        message.isSystemMessage = (Boolean) Utils.parseField(json, "isSystemMessage", "boolean");
        message.isServiceMessage = (Boolean) Utils.parseField(json, "isServiceMessage", "boolean");
        message.isForward = (Boolean) Utils.parseField(json, "isForward", "boolean");
        message.isArchived = (Boolean) Utils.parseField(json, "isArchived", "boolean");
        message.cacheRoomnames = (String) Utils.parseField(json, "cacheRoomnames", "string");
        message.isAudioMessage = (Boolean) Utils.parseField(json, "isAudioMessage", "boolean");
        message.datePlayed = (Timestamp) Utils.parseField(json, "datePlayed", "timestamp");
        message.itemType = (Integer) Utils.parseField(json, "itemType", "integer");
        message.groupTitle = (String) Utils.parseField(json, "groupTitle", "string");
        message.groupActionType = (Integer) Utils.parseField(json, "groupActionType", "integer");
        message.isExpired = (Boolean) Utils.parseField(json, "isExpired", "boolean");
        message.associatedMessageGuid = (String) Utils.parseField(json, "associatedMessageGuid", "string");
        message.associatedMessageType = (String) Utils.parseField(json, "associatedMessageType", "string");
        message.expressiveSendStyleId = (String) Utils.parseField(json, "expressiveSendStyleId", "string");
        message.timeExpressiveSendStyleId = (Timestamp) Utils.parseField(json, "timeExpressiveSendStyleId", "timestamp");

        // Parse handles slightly differently
        if (json.containsKey("handle") && json.get("handle") != null && !String.valueOf(json.get("handle")).equals("null")) {
            message.handle = Handle.fromMap((Map<String, Object>) json.get("handle"), context);
        }

        // Parse attachments slightly differently, too
        if (json.containsKey("attachments") && json.get("attachments") != null && !String.valueOf(json.get("attachments")).equals("null")) {
            message.hasAttachments = ((List<Object>)json.get("attachments")).size() > 0 ? true : false;
        }

        return message;
    }

    public Message save() {
        // Try to find an existing chat before saving it
        Cursor cursor = db.rawQuery("SELECT * FROM message WHERE guid = ? LIMIT 1", new String[]{this.guid});

        if (cursor.moveToFirst()) {
            this.id = cursor.getInt(cursor.getColumnIndex("ROWID"));
        }

        int count = cursor.getCount();
        cursor.close();

        // Save the participant & set the handle ID to the new participant
        if (this.handle != null) {
            this.handle.save(false);
            this.handleId = this.handle.id;
        }

        // If the message doesn't exist, add it
        if (count == 0) {
            // Remove the ID from the map for inserting
            if (this.handleId == null) this.handleId = 0;
            ContentValues map = this.toMap();
            if (map.containsKey("ROWID")) {
                map.remove("ROWID");
            }
            if (map.containsKey("handle")) {
                map.remove("handle");
            }
            this.id = (int) db.insert("message", null, map);
            Log.d("db", "Inserted Message at ROWID: " + String.valueOf(this.id));
        }

        return this;
    }

    //    static Future<List<Attachment>> getAttachments(Message message) async {
//        final Database db = await DBProvider.db.database;
//
//        var res = await db.rawQuery(
//                "SELECT"
//                " attachment.ROWID AS ROWID,"
//                " attachment.guid AS guid,"
//                " attachment.uti AS uti,"
//                " attachment.transferState AS transferState,"
//                " attachment.isOutgoing AS isOutgoing,"
//                " attachment.transferName AS transferName,"
//                " attachment.totalBytes AS totalBytes,"
//                " attachment.isSticker AS isSticker,"
//                " attachment.hideAttachment AS hideAttachment"
//                " FROM message"
//                " JOIN attachment_message_join AS amj ON message.ROWID = amj.messageId"
//                " JOIN attachment ON attachment.ROWID = amj.attachmentId"
//                " WHERE message.ROWID = ?;",
//                [message.id]);
//
//        return (res.isNotEmpty)
//                ? res.map((c) = > Attachment.fromMap(c)).toList()
//        : [];
//    }
//
    @SuppressLint("NewApi")
    public ContentValues toMap() {
        ContentValues map = new ContentValues();
        map.put("ROWID", id);
        map.put("guid", guid);
        map.put("handleId", handleId);
        map.put("text", text);
        map.put("subject", subject);
        map.put("country", country);
        map.put("error", error ? 1 : 0);
        map.put("dateCreated", (dateCreated == null) ? null : dateCreated.toInstant().toEpochMilli());
        map.put("dateRead", (dateRead == null) ? null : dateRead.toInstant().toEpochMilli());
        map.put("dateDelivered", (dateDelivered == null) ? null : dateDelivered.toInstant().toEpochMilli());
        map.put("isFromMe", isFromMe ? 1 : 0);
        map.put("isDelayed", isDelayed ? 1 : 0);
        map.put("isAutoReply", isAutoReply ? 1 : 0);
        map.put("isSystemMessage", isSystemMessage ? 1 : 0);
        map.put("isServiceMessage", isServiceMessage ? 1 : 0);
        map.put("isForward", isForward ? 1 : 0);
        map.put("isArchived", isArchived ? 1 : 0);
        map.put("cacheRoomnames", cacheRoomnames);
        map.put("isAudioMessage", isAudioMessage ? 1 : 0);
        map.put("datePlayed",
                (datePlayed == null) ? null : datePlayed.toInstant().toEpochMilli());
        map.put("itemType", itemType);
        map.put("groupTitle", groupTitle);
        map.put("groupActionType", groupActionType);
        map.put("isExpired", isExpired ? 1 : 0);
        map.put("associatedMessageGuid", associatedMessageGuid);
        map.put("associatedMessageType", associatedMessageType);
        map.put("expressiveSendStyleId", expressiveSendStyleId);
        map.put("timeExpressiveSendStyleId", (timeExpressiveSendStyleId == null)
                ? null
                : timeExpressiveSendStyleId.toInstant().toEpochMilli());
        if (handle == null) {
            map.putNull("handle");
        } else {
            map.put("handle", new JSONObject(handle.toMap()).toString());
        }
        map.put("hasAttachments", hasAttachments ? 1 : 0);
        return map;
    }
}


