package com.bluebubbles.messaging.method_call_handler.handlers;

import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationManagerCompat;

import com.bluebubbles.messaging.MainActivity;

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
        String groupKey = null;
        for (StatusBarNotification statusBarNotification : manager.getActiveNotifications()) {
            Log.d("initial notifs", Integer.toString(statusBarNotification.getId()));
            if (statusBarNotification.getNotification().extras.getString("chatGuid") != null && statusBarNotification.getNotification().extras.getString("chatGuid").contains(Objects.requireNonNull(call.argument("chatGuid")))) {
                NotificationManagerCompat.from(context).cancel(statusBarNotification.getId());
                groupKey = statusBarNotification.getGroupKey();
            } else {
                Log.d("notification clearing", statusBarNotification.getGroupKey());
            }
        }
        int counter = 0;
        for (StatusBarNotification statusBarNotification : manager.getActiveNotifications()) {
            Log.d("updated notifs", Integer.toString(statusBarNotification.getId()));
            if (statusBarNotification.getGroupKey().equals(groupKey)) {
                counter++;
            }
        }

        if (counter == 1) {
            Log.d("test", "canceled group summary");
            NotificationManagerCompat.from(context).cancel(-1);
        }
        result.success("");
    }
}
