package com.bluebubbles.messaging.method_call_handler.handlers;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.os.Build;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class CreateNotificationChannel implements Handler{
    public static String TAG = "create-notif-channel";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public CreateNotificationChannel(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        createNotificationChannel(call.argument("channel_name"), call.argument("channel_description"), call.argument("CHANNEL_ID"), context);
        result.success("");
    }

    public static void createNotificationChannel(String channel_name, String channel_description, String CHANNEL_ID, Context context) {
        // Create the NotificationChannel, but only on API 26+ because
        // the NotificationChannel class is new and not in the support library
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            CharSequence name = channel_name;
            String description = channel_description;
            int importance = NotificationManager.IMPORTANCE_HIGH;
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, name, importance);
            channel.setDescription(description);
            // Register the channel with the system; you can't change the importance
            // or other notification behaviors after this
            NotificationManager notificationManager = context.getSystemService(NotificationManager.class);
            notificationManager.createNotificationChannel(channel);
        }
    }
}
