package com.example.bluebubble_messages;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Binder;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.SystemClock;
import android.preference.PreferenceManager;
import android.util.Log;

import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;

import com.google.firebase.messaging.RemoteMessage;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.FlutterCallbackInformation;
import io.flutter.view.FlutterMain;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.FlutterRunArguments;

import static com.example.bluebubble_messages.MainActivity.CHANNEL;
import static com.example.bluebubble_messages.MainActivity.engine;

public class FirebaseMessagingService extends com.google.firebase.messaging.FirebaseMessagingService {
    private static final String TAG = "MyFirebaseMsgService";
    private LocalBroadcastManager broadcaster;
    private BackgroundService backgroundService;
    ArrayList<String> processedGuids = new ArrayList<String>();

    protected ServiceConnection mServerConn = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder binder) {
            backgroundService = ((BackgroundService.LocalBinder) binder).getService();
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            backgroundService = null;
        }
    };


    @Override
    public void onCreate() {
        Log.d("isolate", "firebase service spawned");
        broadcaster = LocalBroadcastManager.getInstance(this);
        getApplicationContext().bindService(new Intent(getApplicationContext(), BackgroundService.class), mServerConn, Context.BIND_AUTO_CREATE);
    }

    @Override
    public void onDestroy() {
        Log.d("isolate", "firebase service destroyed");
        super.onDestroy();
    }

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        // Check if message contains a data payload.

        JSONObject jObject = null;
        Map<String, Object> data = null;
        try {
            jObject = new JSONObject(remoteMessage.getData().get("data"));
            data = (Map<String, Object>) BackgroundService.jsonToMap(jObject);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        if(data == null) return;
        if (remoteMessage.getData().size() > 0 && !remoteMessage.getData().get("type").equals("new-server")) {
            if( processedGuids.contains(data.get("guid"))) return;
            processedGuids.add((String) data.get("guid"));
            Log.d("notification", "on message received " + processedGuids.toString());
            Intent intent = new Intent("MyData");
            intent.putExtra("type", remoteMessage.getData().get("type"));
            intent.putExtra("data", remoteMessage.getData().get("data"));
            new Handler(Looper.getMainLooper()).post(new Runnable() {
                @Override
                public void run() {
                    new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod(intent.getExtras().getString("type"), intent.getExtras().getString("data"));
                }
            });
            if(backgroundService != null) {
                backgroundService.saveMessage(remoteMessage.getData().get("data"));
            } else {
                Log.d("isolate", "could not find background service");
            }
        }
    }


    @Override
    public void onTaskRemoved(Intent rootIntent) {
        Log.d("firebase", "task removed");
        super.onTaskRemoved(rootIntent);
    }


}
