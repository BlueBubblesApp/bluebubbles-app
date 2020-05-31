package com.example.bluebubble_messages;


import android.content.ContentValues;
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
    boolean isExpired;
    String associatedMessageGuid;
    String associatedMessageType;
    String expressiveSendStyleId;
    Date timeExpressiveSendStyleId;
    Handle handle;
    boolean hasAttachments;

    public static Message fromMap(String data) throws JSONException {
        Map<String, Object> json = BackgroundService.jsonToMap(data);
        Log.d("db", "converting from map " + String.valueOf(json.get("handle") != "null"));
        Message message = new Message();
        message.id = json.containsKey("ROWID") ? (Integer) json.get("ROWID") : null;
        message.guid = (String) json.get("guid");
        message.handleId = (json.get("handleId") != null) ? Integer.parseInt((String) json.get("handleId")) : 0;
        message.text = (String) json.get("text");
        message.subject = json.containsKey("subject") ? (String) json.get("subject") : null;
        message.country = json.containsKey("country") ? (String) json.get("country") : null;
        message.error = (Boolean.valueOf((String) json.get("error")) instanceof Boolean) ? Boolean.valueOf((String) json.get("error")) : (Integer.parseInt((String) json.get("error")) == 1 ? true : false);
        message.dateCreated = json.containsKey("dateCreated")
                ? json.get("dateCreated") == null ? null : new Timestamp(Long.valueOf((String) json.get("dateCreated")))
                : null;
        message.dateRead = json.containsKey("dateRead") ? json.get(json.get("dateRead")) == null ? null : new Timestamp(Long.valueOf((String) json.get("dateRead"))) : null;
        message.dateDelivered =
                json.containsKey("dateDelivered")
                        ? json.get("dateDelivered") == null || json.get("dateDelivered") == "null" ? null : new Timestamp(Long.valueOf((String) json.get("dateDelivered")))
                        : null;
        message.isFromMe = (Boolean.valueOf((String) json.get("isFromMe")) instanceof Boolean)
                ? Boolean.valueOf((String) json.get("isFromMe"))
                : (((Integer) json.get("isFromMe") == 1) ? true : false);
        message.isDelayed = (Boolean.valueOf((String) json.get("isDelayed")) instanceof Boolean)
                ? Boolean.valueOf((String) json.get("isDelayed"))
                : (((Integer) json.get("isDelayed") == 1) ? true : false);
        message.isAutoReply = (Boolean.valueOf((String) json.get("isAutoReply")) instanceof Boolean)
                ? Boolean.valueOf((String) json.get("isAutoReply"))
                : (((Integer) json.get("isAutoReply") == 1) ? true : false);
        message.isSystemMessage =
                (Boolean.valueOf((String) json.get("isSystemMessage")) instanceof Boolean)
                        ? Boolean.valueOf((String) json.get("isSystemMessage"))
                        : ((Integer.parseInt((String) json.get("isSystemMessage")) == 1) ? true : false);
        message.isServiceMessage =
                (Boolean.valueOf((String) json.get("isServiceMessage")) instanceof Boolean)
                        ? Boolean.valueOf((String) json.get("isServiceMessage"))
                        : ((Integer.parseInt((String) json.get("isServiceMessage")) == 1) ? true : false);
        message.isForward = (Boolean.valueOf((String) json.get("isForward")) instanceof Boolean)
                ? Boolean.valueOf((String) json.get("isForward"))
                : ((Integer.parseInt((String) json.get("isForward")) == 1) ? true : false);
        message.isArchived =
                (Boolean.valueOf((String) json.get("isArchived")) instanceof Boolean)
                        ? Boolean.valueOf((String) json.get("isArchived"))
                        : ((Integer.parseInt((String) json.get("isArchived")) == 1) ? true : false);
        message.cacheRoomnames =
                json.containsKey("cacheRoomnames") ? (String) json.get("cacheRoomnames") : null;
        message.isAudioMessage = (Boolean.valueOf((String) json.get("isAudioMessage")) instanceof Boolean)
                ? Boolean.valueOf((String) json.get("isAudioMessage"))
                : ((Integer.parseInt((String) json.get("isAudioMessage")) == 1) ? true : false);
        message.datePlayed =
                json.containsKey("datePlayed")
                        ? json.get("datePlayed") == "null" ? null : new Timestamp(Long.valueOf((String) json.get("datePlayed")))
                        : null;
        message.itemType = json.containsKey("itemType") ? Integer.parseInt((String) json.get("itemType")) : null;
        message.groupTitle = json.containsKey("groupTitle") ? (String) json.get("groupTitle") : null;
        message.isExpired = (Boolean.valueOf((String) json.get("isExpired")) instanceof Boolean)
                ? Boolean.valueOf((String) json.get("isExpired"))
                : ((Integer.parseInt((String) json.get("isExpired")) == 1) ? true : false);
        message.associatedMessageGuid =
                json.containsKey("associatedMessageGuid")
                        ? (String) json.get("associatedMessageGuid")
                        : null;
        message.associatedMessageType =
                json.containsKey("associatedMessageType")
                        ? (String) json.get("associatedMessageType")
                        : null;
        message.expressiveSendStyleId =
                json.containsKey("expressiveSendStyleId")
                        ? (String) json.get("expressiveSendStyleId")
                        : null;
        message.timeExpressiveSendStyleId =
                json.containsKey("timeExpressiveSendStyleId")
                        ? json.get("timeExpressiveSendStyleId") == "null" ? null : new Timestamp(Long.valueOf((String) json.get("timeExpressiveSendStyleId")))
                        : null;
        Log.d("db", "handle map is " + BackgroundService.jsonToMap((String) json.get("handle")).toString());
        message.handle = json.containsKey("handle")
                ? (json.get("handle") != "null" ? Handle.fromMap(BackgroundService.jsonToMap((String) json.get("handle"))) : null)
                : null;
        message.hasAttachments = json.containsKey("attachments")
                ? (((new JSONArray((String) json.get("attachments"))).length() > 0) ? true : false)
                : false;
        return message;
    }

    public Message save(SQLiteDatabase db) {
        // Try to find an existing chat before saving it
        Cursor existing = db.rawQuery("SELECT * FROM message WHERE guid = ? LIMIT 1", new String[]{this.guid});

        if (existing.moveToFirst()) {
            this.id = existing.getInt(existing.getColumnIndex("ROWID"));
        }

        // Save the participant & set the handle ID to the new participant
        if (this.handle != null) {
            Log.d("db", "handle address is " + this.handle.address);
            this.handle.save(db, false);
            this.handleId = this.handle.id;
        }

        // If it already exists, update it
        if (!existing.moveToFirst()) {
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
    public ContentValues toMap() {
        ContentValues map = new ContentValues();
        map.put("ROWID", id);
        map.put("guid", guid);
        map.put("handleId", handleId);
        map.put("text", text);
        map.put("subject", subject);
        map.put("country", country);
        map.put("error", error ? 1 : 0);
        map.put("dateCreated", (dateCreated == null) ? null : (int) dateCreated.getTime());
        map.put("dateRead", (dateRead == null) ? null : (int) dateRead.getTime());
        map.put("dateDelivered", (dateDelivered == null) ? null : (int) dateDelivered.getTime());
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
                (datePlayed == null) ? null : datePlayed.getTime());
        map.put("itemType", itemType);
        map.put("groupTitle", groupTitle);
        map.put("isExpired", isExpired ? 1 : 0);
        map.put("associatedMessageGuid", associatedMessageGuid);
        map.put("associatedMessageType", associatedMessageType);
        map.put("expressiveSendStyleId", expressiveSendStyleId);
        map.put("timeExpressiveSendStyleId", (timeExpressiveSendStyleId == null)
                ? null
                : timeExpressiveSendStyleId.getTime());
        if (handle == null) {
            map.putNull("handle");
        } else {
            map.put("handle", new JSONObject(handle.toMap()).toString());
        }
        map.put("hasAttachments", hasAttachments ? 1 : 0);
        return map;
    }
}


