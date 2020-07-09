package com.example.bluebubble_messages;

import android.app.RemoteInput;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.IBinder;
import android.util.Log;

import androidx.core.app.NotificationManagerCompat;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodChannel;

import static com.example.bluebubble_messages.MainActivity.CHANNEL;
import static com.example.bluebubble_messages.MainActivity.engine;

public class ReplyReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {

        if (intent.getType().equals("reply")) {
            Bundle remoteInput = RemoteInput.getResultsFromIntent(intent);
            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
            notificationManager.cancel(intent.getExtras().getInt("id"));
            Map<String, Object> params = new HashMap<>();

            params.put("chat", intent.getExtras().getString("chatGuid"));
            params.put("text", remoteInput.getString("key_text_reply"));

            IBinder binder = peekService(context, new Intent(context, BackgroundService.class));
            if (binder != null) {
                Log.d("replyReceiver", "binder != null");
                MethodChannel channel = ((BackgroundService.LocalBinder) binder).getService().backgroundChannel;
                if (channel != null) {
                    Log.d("replyReceiver", "channel != null");
                    channel.invokeMethod("reply", params);
                } else if(engine != null){
                    Log.d("replyReceiver", "channel == null");
                    new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("reply", params);
                }
            } else if (engine != null) {
                Log.d("replyReceiver", "binder == null");
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("reply", params);
            }
        } else if (intent.getType().equals("markAsRead")) {
            Map<String, Object> params = new HashMap<>();
            params.put("chat", intent.getExtras().getString("chatGuid"));
            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
            notificationManager.cancel(intent.getExtras().getInt("id"));
            IBinder binder = peekService(context, new Intent(context, BackgroundService.class));
            if (binder != null) {
                MethodChannel channel = ((BackgroundService.LocalBinder) binder).getService().backgroundChannel;
                if (channel != null) {
                    channel.invokeMethod("markAsRead", params);
                } else if (engine != null) {
                    new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("markAsRead", params);
                }
            } else if (engine != null) {
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("markAsRead", params);
            }
        }
    }
}
