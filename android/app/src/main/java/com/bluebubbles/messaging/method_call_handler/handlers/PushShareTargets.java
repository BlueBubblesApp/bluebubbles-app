package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.os.Build;

import androidx.annotation.RequiresApi;

import com.bluebubbles.messaging.sharing.Contact;
import com.bluebubbles.messaging.sharing.ShareShortcutManager;

import java.util.ArrayList;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class PushShareTargets implements Handler {
    public static String TAG = "push-share-targets";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;


    public PushShareTargets(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    @Override
    public void Handle() {
        String name = call.argument("title");
        String guid = call.argument("guid");
        byte[] icon = call.argument("icon");

        ShareShortcutManager.publishShareTarget(context, new Contact(name, guid, icon));
        result.success(null);
    }
}
