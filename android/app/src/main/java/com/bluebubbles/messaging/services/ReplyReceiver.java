package com.bluebubbles.messaging.services;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.RemoteInput;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.service.notification.StatusBarNotification;

import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationManagerCompat;

import com.bluebubbles.messaging.workers.NotificationWorker;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodChannel;

import static android.content.Context.NOTIFICATION_SERVICE;
import static com.bluebubbles.messaging.MainActivity.CHANNEL;
import static com.bluebubbles.messaging.MainActivity.engine;

public class ReplyReceiver extends BroadcastReceiver {

    @RequiresApi(api = Build.VERSION_CODES.P)
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) return;

        if (intent.getType().equals("reply")) {
            Bundle remoteInput = RemoteInput.getResultsFromIntent(intent);
            NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);
            NotificationManager notificationManager = (NotificationManager) context.getSystemService(NOTIFICATION_SERVICE);
            for (StatusBarNotification notification : notificationManager.getActiveNotifications()) {
                if (notification.getId() == intent.getExtras().getInt("id")) {
                    Notification.Builder builder = Notification.Builder.recoverBuilder(context, notification.getNotification());
                    Notification.MessagingStyle style = (Notification.MessagingStyle) builder.getStyle();
                    style.addMessage(new Notification.MessagingStyle.Message(remoteInput.getString("key_text_reply"), System.currentTimeMillis() / 1000, "You"));
                    builder.setStyle(style);
                    builder.setOnlyAlertOnce(true);


                    notificationManagerCompat.notify(notification.getId(), builder.build());

                }
            }
            Map<String, Object> params = new HashMap<>();

            params.put("chat", intent.getExtras().getString("chatGuid"));
            params.put("text", remoteInput.getString("key_text_reply"));

            if (engine != null) {
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("reply", params);
            } else {
                NotificationWorker.createWorker(context.getApplicationContext(), "reply", params);
            }
        } else if (intent.getType().equals("markAsRead")) {
            Map<String, Object> params = new HashMap<>();
            params.put("chat", intent.getExtras().getString("chatGuid"));
            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
            notificationManager.cancel(intent.getExtras().getInt("id"));
            if (engine != null) {
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("markAsRead", params);
            } else {
                NotificationWorker.createWorker(context.getApplicationContext(), "markAsRead", params);

            }
        } else if(intent.getType().equals("alarm")) {

            Map<String, Object> params = new HashMap<>();
            params.put("id", intent.getExtras().getInt("id"));
            if (engine != null) {
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("alarm-wake", params);
            } else {
                NotificationWorker.createWorker(context.getApplicationContext(), "alarm-wake", params);
            }
        }
    }
}
