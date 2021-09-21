package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.os.Build;
import android.util.Log;

import androidx.annotation.RequiresApi;

import com.bluebubbles.messaging.MainActivity;
import com.bluebubbles.messaging.helpers.HelperUtils;

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
        HelperUtils.tryCancelNotifications(context, null, chatGuid);
        result.success("");
    }
}
