package com.bluebubbles.messaging.services;

import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.work.Data;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;

import com.bluebubbles.messaging.workers.FCMWorker;
import com.google.firebase.messaging.RemoteMessage;

import io.flutter.plugin.common.MethodChannel;

import static com.bluebubbles.messaging.MainActivity.CHANNEL;
import static com.bluebubbles.messaging.MainActivity.engine;

public class FirebaseMessagingService extends com.google.firebase.messaging.FirebaseMessagingService {
    private static final String TAG = "MyFirebaseMsgService";

    @Override
    public void onCreate() {
        Log.d("BlueBubblesApp", "FCM service spawned");
        super.onCreate();
    }

    @Override
    public void onDestroy() {
        Log.d("BlueBubblesApp", "FCM service destroyed");
        super.onDestroy();
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        Log.d("BlueBubblesApp", "FCM task removed");
        super.onTaskRemoved(rootIntent);
    }

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        if (remoteMessage == null) return;
        Log.d("BlueBubblesApp", "Received new message from FCM");
        Log.d("BlueBubblesApp", "Message type: " + remoteMessage.getData().get("type"));
        // Check if message contains a data payload.
        if (remoteMessage.getData().size() > 0 && !remoteMessage.getData().get("type").equals("new-server")) {
            Intent intent = new Intent("MyData");
            intent.putExtra("type", remoteMessage.getData().get("type"));
            intent.putExtra("data", remoteMessage.getData().get("data"));
            new Handler(Looper.getMainLooper()).post(new Runnable() {
                @Override
                public void run() {
                    if (engine != null) {
                        Log.d("BlueBubblesApp", "Invoking method of type: " + intent.getExtras().getString("type"));
                        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod(intent.getExtras().getString("type"), intent.getExtras().getString("data"));
                    }
                }
            });
            Log.d("BlueBubblesApp", "Creating FCM worker");
            FCMWorker.createWorker(getApplicationContext(), remoteMessage.getData().get("type"), remoteMessage.getData().get("data"));
        }
    }
}
