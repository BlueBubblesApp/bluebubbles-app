package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class FetchMessagesHandler implements Handler{
    public static String TAG = "fetch-messages";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public FetchMessagesHandler(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {

    }
}
