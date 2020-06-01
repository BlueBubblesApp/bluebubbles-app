package com.example.bluebubble_messages;

import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Binder;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;
import android.widget.Toast;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.FlutterCallbackInformation;
import io.flutter.view.FlutterMain;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.FlutterRunArguments;

public class BackgroundService extends Service {
    static boolean isRunning = false;
    public boolean isAlive = false;
    SQLiteDatabase db;
    public LocalBroadcastManager broadcaster;

    public void stopDB() {
        if(db != null) {
            db.close();
        }
        db = null;
    }

    public void openDB() {
        db = SQLiteDatabase.openDatabase("/data/data/com.example.bluebubble_messages/app_flutter/chat.db", null, 0);
    }

    public class LocalBinder extends Binder {
        BackgroundService getService() {
            return BackgroundService.this;
        }
    }


    @Override
    public void onCreate() {
//       startForegroundService()
        Log.d("isolate", "created background service");
        openDB();
        broadcaster = LocalBroadcastManager.getInstance(this);
    }

    public static Map<String, Object> jsonToMap(String t) throws JSONException {

        Map<String, Object> map = new HashMap<>();
        JSONObject jObject = new JSONObject(t);
        Iterator<?> keys = jObject.keys();

        while (keys.hasNext()) {
            String key = (String) keys.next();
            String value = jObject.getString(key);
            map.put(key, value);

        }
        return map;
    }


    public void saveMessage(String _data) {
        if (isAlive || db == null) return;
        Map<String, Object> data = null;
        try {
            data = jsonToMap(_data);
        } catch (JSONException e) {
            e.printStackTrace();
        }
//        if ((new JSONArray (data.get("chats")).size()) == 0) return;
        JSONArray chats = null;
        try {
            chats = new JSONArray((String) data.get("chats"));
            Log.d("db", "chats is " + chats.get(0).toString());
        } catch (JSONException e) {
            return;
        }
//        Chat chat = Chat.findOne({"guid": data["chats"][0]["guid"]});
//        List<Map<String, Object>> chats = (List<Map<String, Object>>) data.get("chats");
        Cursor result;
        try {
            result = db.rawQuery("SELECT * FROM chat WHERE guid = ? LIMIT 1", new String[]{((JSONObject) chats.get(0)).getString("guid")});
        } catch (JSONException e) {
            return;
        }
        if (!result.moveToFirst()) {
            Log.d("db", "chat not found");
            return;
        }
        Chat chat = Chat.fromCursor(result);

//        String title = chat.guid;

//        SocketManager().handleNewMessage(data, chat);
//
//        Message message = Message.fromMap(data);
        Message message = null;
        try {
            message = Message.fromMap(_data);
        } catch (JSONException e) {
            return;
        }
        Log.d("db", "new message " + message.text);
        chat.save(db, true);
        chat.addMessage(db, message);
        //TODO add attachments
//            try {
//                JSONArray attachments = new JSONArray(data.get("attachments"));
//                for(int i = 0; i < attachments.length(); i++ ) {
//                    Attachment file = A
//                }
//            } catch (JSONException e) {
//                e.printStackTrace();
//            }
//                }
//                NewMessageManager().updateWithMessage(chat, message);
//      });
//            }
//        }
    }


    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i("LocalService", "Received start id " + startId + ": " + intent);
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return mBinder;
    }

    private final IBinder mBinder = new LocalBinder();
}
