package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import androidx.core.content.FileProvider;

import java.io.File;
import java.util.HashMap;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ShareText implements Handler{

    public static String TAG = "share-text";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public ShareText(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        HashMap<String, String> argsMap = (HashMap<String, String>) call.arguments;

        Intent shareIntent = new Intent(Intent.ACTION_SEND);
        shareIntent.putExtra(Intent.EXTRA_TEXT, argsMap.get("text"));
        shareIntent.putExtra(Intent.EXTRA_SUBJECT, argsMap.get("subject"));
        shareIntent.setType("text/plain");


        context.startActivity(Intent.createChooser(shareIntent, argsMap.get("subject")));
    }
}
