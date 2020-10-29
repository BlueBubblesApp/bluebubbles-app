package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;

import androidx.core.app.NotificationManagerCompat;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ClearSocketIssue implements Handler {
    public static String TAG = "clear-socket-issue";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public ClearSocketIssue(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);
        notificationManagerCompat.cancel(1000);
        result.success("");
    }
}
