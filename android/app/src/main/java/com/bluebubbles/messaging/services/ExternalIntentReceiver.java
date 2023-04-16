package com.bluebubbles.messaging.services;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import java.util.HashMap;

import androidx.annotation.RequiresApi;

import com.bluebubbles.messaging.helpers.HelperUtils;
import io.flutter.plugin.common.MethodChannel;

public class ExternalIntentReceiver extends BroadcastReceiver {
    final String TAG = "ExternalReceiver";

    @RequiresApi(api = Build.VERSION_CODES.P)
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) return;

        String action = intent.getAction();
        Log.d(TAG, "Received intent action " + action);
        if (action == "com.bluebubbles.external.GET_SERVER_URL") {
            String identifier = intent.getExtras().getString("id");
            String password = intent.getExtras().getString("password");
            HelperUtils.getServerUrl(context, password, identifier, new MethodChannel.Result() {
                @Override
                public void success(Object result) {
                    Log.d(TAG, "Got URL: " + result.toString());
                    Intent intent = new Intent();
                    intent.setAction("net.dinglisch.android.taskerm.BB_SERVER_URL");
                    intent.putExtra("url", result.toString());
                    intent.putExtra("id", identifier);
                    context.sendBroadcast(intent);
                }

                @Override
                public void error(String errorCode, String errorMessage, Object errorDetails) {}

                @Override
                public void notImplemented() {}
            });
        }

        intent.replaceExtras(new Bundle());
        intent.setType("");
        intent.setAction("");
        intent.setData(null);
        intent.setFlags(0);
    }
}
