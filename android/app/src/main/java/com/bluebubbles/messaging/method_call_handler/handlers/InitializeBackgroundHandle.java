package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.util.Log;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class InitializeBackgroundHandle implements Handler{

    public static String TAG = "initialize-background-handle";
    public static String BACKGROUND_SERVICE_SHARED_PREF = "BACKGROUND_SERVICE_SHARED_PREF";
    public static String BACKGROUND_HANDLE_SHARED_PREF_KEY = "BACKGROUND_HANDLE_SHARED_PREF_KEY";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public InitializeBackgroundHandle(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }


    @Override
    public void Handle() {
        Long callbackHandle;
        if (call.argument("handle").getClass() == Long.class) {
            callbackHandle = call.argument("handle");
        } else if (call.argument("handle").getClass() == Integer.class) {
            callbackHandle = ((Integer) call.argument("handle")).longValue();
        } else {
            callbackHandle = Long.valueOf(call.argument("handle"));
        }

        context.getSharedPreferences(BACKGROUND_SERVICE_SHARED_PREF, Context.MODE_PRIVATE)
                .edit()
                .putLong(BACKGROUND_HANDLE_SHARED_PREF_KEY, (Long) callbackHandle)
                .apply();
        result.success("");
    }
}
