package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;

import androidx.core.app.NotificationManagerCompat;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ClearFailedToSend implements Handler {
    public static String TAG = "clear-failed-to-send";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public ClearFailedToSend(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);
        notificationManagerCompat.cancel(1001);
        result.success("");
    }
}
