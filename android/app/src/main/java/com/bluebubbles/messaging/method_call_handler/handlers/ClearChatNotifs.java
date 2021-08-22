package com.bluebubbles.messaging.method_call_handler.handlers;

import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationManagerCompat;

import com.bluebubbles.messaging.MainActivity;
import com.bluebubbles.messaging.method_call_handler.handlers.NewMessageNotification;

import java.util.Objects;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ClearChatNotifs implements Handler {


    public static String TAG = "clear-chat-notifs";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public ClearChatNotifs(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    public void Handle() {
        String chatGuid = (String) call.argument("chatGuid");
        Log.d(TAG, "Clearing notifications for chat: " + chatGuid);

        NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
        NotificationManager manager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
        for (StatusBarNotification statusBarNotification : manager.getActiveNotifications()) {
            // Only clear the notification if the Chat GUIDs match
            if (statusBarNotification.getNotification().extras.getString("chatGuid") != null && statusBarNotification.getNotification().extras.getString("chatGuid").contains(Objects.requireNonNull(chatGuid))) {
                Log.d(TAG, "Cancelling notification with ID: " + statusBarNotification.getId());
                notificationManager.cancel(statusBarNotification.getTag(), statusBarNotification.getId());
            }
        }

        result.success("");

       // If there are no more notifications (only the group is left). Clear the group
       StatusBarNotification[] notifications = manager.getActiveNotifications();
       Log.d(TAG, "Leftover Notifications: " + notifications.length);
       if (manager.getActiveNotifications().length == 1 && notifications[0].getId() == -1) {
           Log.d(TAG, "Cancelling the notification group...");
           notificationManager.cancel(-1);
       }
    }
}
