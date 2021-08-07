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
        NotificationManager manager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
        Integer notifId = null;
        for (StatusBarNotification statusBarNotification : manager.getActiveNotifications()) {
            if (statusBarNotification.getNotification().extras.getString("chatGuid") != null && statusBarNotification.getNotification().extras.getString("chatGuid").contains(Objects.requireNonNull(call.argument("chatGuid")))) {
                notifId = statusBarNotification.getId();
                NotificationManagerCompat.from(context).cancel(statusBarNotification.getId());
            } else {
                Log.d("notification clearing", statusBarNotification.getGroupKey());
            }
        }

        result.success("");

        for (StatusBarNotification statusBarNotification : manager.getActiveNotifications()) {
            if (NewMessageNotification.notificationTag == statusBarNotification.getTag() && statusBarNotification.getId() != notifId) {
                return;
            }
        }

        NotificationManagerCompat.from(context).cancel(-1);
    }
}
