package com.example.bluebubble_messages;

import android.content.Context;
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
import java.util.ArrayList;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.FlutterCallbackInformation;
import io.flutter.view.FlutterMain;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.FlutterRunArguments;

public class BackgroundService extends Service {
    // static boolean isRunning = false;
    public boolean isAlive = false;
    public LocalBroadcastManager broadcaster;
    private SQLiteDatabase db;

    public class LocalBinder extends Binder {
        BackgroundService getService() {
            return BackgroundService.this;
        }
    }


    @Override
    public void onCreate() {
//       startForegroundService()
        Log.d("isolate", "created background service");

        DatabaseHelper helper = DatabaseHelper.getInstance(this);
        this.db = helper.getWritableDatabase();

        broadcaster = LocalBroadcastManager.getInstance(this);
    }

    public void saveMessage(String _data) {
        if (isAlive || this.db == null) return;
        Map<String, Object> data = null;
        try {
            JSONObject jObject = new JSONObject(_data);
            data = (Map<String, Object>) jsonToMap(jObject);
        } catch (JSONException e) {
            e.printStackTrace();
            return;
        }

        
        try {
            this.db.beginTransaction();

            // Decode the message
            Message message = Message.fromMap(data, this);

            // Iterate each chat and save the message
            List<Map<String, Object>> chats = (List<Map<String, Object>>) data.get("chats");
            for (int i = 0; i < chats.size(); i++) {
                Map<String, Object> chatMap = chats.get(i);
                Chat chat = Chat.fromMap(chatMap, this);

                chat.save(true);
                chat.addMessage(message);
            }

            this.db.setTransactionSuccessful();
        } catch (Exception ex) {
            ex.printStackTrace();
        } finally {
            this.db.endTransaction();
        }
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

    public static Map<String, Object> jsonToMap(JSONObject json) throws JSONException {
        Map<String, Object> retMap = new HashMap<String, Object>();

        if (json != JSONObject.NULL) {
            retMap = toMap(json);
        }
        return retMap;
    }

    public static Map<String, Object> toMap(JSONObject object) throws JSONException {
        Map<String, Object> map = new HashMap<String, Object>();

        Iterator<String> keysItr = object.keys();
        while (keysItr.hasNext()) {
            String key = keysItr.next();
            Object value = object.get(key);

            if (value instanceof JSONArray) {
                value = toList((JSONArray) value);
            } else if (value instanceof JSONObject) {
                value = toMap((JSONObject) value);
            }
            map.put(key, value);
        }
        return map;
    }

    public static List<Object> toList(JSONArray array) throws JSONException {
        List<Object> list = new ArrayList<Object>();
        for (int i = 0; i < array.length(); i++) {
            Object value = array.get(i);
            if (value instanceof JSONArray) {
                value = toList((JSONArray) value);
            } else if (value instanceof JSONObject) {
                value = toMap((JSONObject) value);
            }
            list.add(value);
        }
        return list;
    }

    private final IBinder mBinder = new LocalBinder();
}
