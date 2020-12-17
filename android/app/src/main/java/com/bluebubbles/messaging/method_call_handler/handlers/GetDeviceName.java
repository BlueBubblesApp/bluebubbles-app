package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.os.Build;
import android.util.Log;

import androidx.annotation.RequiresApi;

import java.util.Objects;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class GetDeviceName implements Handler {


    public static String TAG = "get-device-name";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public GetDeviceName(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    public void Handle() {
        String name = android.os.Build.MANUFACTURER + "_" + android.os.Build.MODEL;
        result.success(name);
    }
}
