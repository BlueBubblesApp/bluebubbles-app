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
import android.util.Log;

import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationManagerCompat;

import com.bluebubbles.messaging.workers.NotificationWorker;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.MethodChannel;

import static android.content.Context.NOTIFICATION_SERVICE;
import static com.bluebubbles.messaging.MainActivity.CHANNEL;
import static com.bluebubbles.messaging.MainActivity.engine;
import com.bluebubbles.messaging.method_call_handler.handlers.NewMessageNotification;

public class ReplyReceiver extends BroadcastReceiver {

    final String TAG = "ReplyReceiver";

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
            Integer existingId = intent.getExtras().getInt("id");
            String chatGuid = intent.getExtras().getString("chatGuid");
            Log.d(TAG, "Marking chat notification as read: " + intent.getExtras().getString("chatGuid"));
            Log.d(TAG, "Finding notifications with ID: " + existingId);

            // Clear the chat notification by finding the notification by Tag/ID and cancelling it
            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
            NotificationManager manager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
            for (StatusBarNotification statusBarNotification : manager.getActiveNotifications()) {
                if (NewMessageNotification.notificationTag.equals(statusBarNotification.getTag()) && statusBarNotification.getId() == existingId) {
                    notificationManager.cancel(NewMessageNotification.notificationTag, existingId);
                    break;
                }
            }

            // If there are no more notifications (only the group is left). Clear the group
            StatusBarNotification[] notifications = manager.getActiveNotifications();
            Log.d(TAG, "Leftover Notifications: " + notifications.length);
            if (manager.getActiveNotifications().length == 1 && notifications[0].getId() == -1) {
                Log.d(TAG, "Cancelling the notification group...");
                notificationManager.cancel(-1);
            }

            // Build params to send to Dart for it to handle whatever it needs
            Map<String, Object> params = new HashMap<>();
            params.put("chat", chatGuid);

            // Invoke the Dart isolate to clear the notification from that side
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
