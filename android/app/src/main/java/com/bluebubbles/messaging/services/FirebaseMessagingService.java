package com.bluebubbles.messaging.services;

import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.work.Data;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;

import com.bluebubbles.messaging.helpers.NotifyRunnable;
import com.google.firebase.messaging.RemoteMessage;

import io.flutter.plugin.common.MethodChannel;

import static com.bluebubbles.messaging.MainActivity.CHANNEL;
import static com.bluebubbles.messaging.MainActivity.engine;
import com.bluebubbles.messaging.helpers.HelperUtils;
import io.flutter.plugin.common.MethodChannel.Result;
import java.util.concurrent.CountDownLatch;
import android.content.SharedPreferences;

public class FirebaseMessagingService extends com.google.firebase.messaging.FirebaseMessagingService {
    private static final String TAG = "MyFirebaseMsgService";

    @Override
    public void onCreate() {
        Log.d("BlueBubblesApp", "FCM service spawned");
        if (ContextHolder.getApplicationContext() == null) {
            ContextHolder.setApplicationContext(getApplicationContext());
        }
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
        String type = remoteMessage.getData().get("type");
        Log.d("BlueBubblesApp", "Message type: " + type);
        Context context = getApplicationContext();
        if (ContextHolder.getApplicationContext() == null && context != null) {
            ContextHolder.setApplicationContext(context);
        }
        Intent onBackgroundMessageIntent = new Intent(context, FlutterFirebaseMessagingBackgroundService.class);
        onBackgroundMessageIntent.putExtra("notification", remoteMessage);
        FlutterFirebaseMessagingBackgroundService.enqueueMessageProcessing(context, onBackgroundMessageIntent);
        // check if user wanted to send events to Tasker
        SharedPreferences mPrefs = context.getSharedPreferences("FlutterSharedPreferences", 0);
        Boolean sendToTasker = mPrefs.getBoolean("flutter.sendEventsToTasker", false);
        if (sendToTasker) {
            HelperUtils.getServerUrl(context, mPrefs.getString("flutter.guidAuthKey", ""), "", new Result() {
                @Override
                public void success(Object result) {
                    if (result == null) return;

                    Intent intent = new Intent();
                    intent.setAction("net.dinglisch.android.taskerm.BB_EVENT");
                    intent.putExtra("url", result.toString());
                    intent.putExtra("event", type);
                    intent.putExtra("data", remoteMessage.getData().get("data"));
                    context.sendBroadcast(intent);
                }

                @Override
                public void error(String errorCode, String errorMessage, Object errorDetails) {}

                @Override
                public void notImplemented() {}
            });
        }
    }
}
