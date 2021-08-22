package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class OpenLink implements Handler {
    public static String TAG = "open-link";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public OpenLink(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(call.argument("link")));
        if ((Boolean) call.argument("forceBrowser")) {
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            i.setPackage("com.android.chrome");
            try {
                context.startActivity(i);
            } catch (ActivityNotFoundException e) {
                // Chrome is probably not installed
                // Try with the default browser
                i.setPackage(null);
                context.startActivity(i);
            }
        } else {
            context.startActivity(i);
        }
        result.success("");
    }
}
