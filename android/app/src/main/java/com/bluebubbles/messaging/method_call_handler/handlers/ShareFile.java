package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import androidx.core.content.FileProvider;

import java.io.File;
import java.util.HashMap;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class ShareFile implements Handler{

    public static String TAG = "share-file";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public ShareFile(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        HashMap<String, String> argsMap = (HashMap<String, String>) call.arguments;
        File requestFile = new File(argsMap.get("filepath"));
        Uri shareContentUri = FileProvider.getUriForFile(
                context,
                "com.bluebubbles.messaging.fileprovider",
                requestFile
        );
        Intent shareIntent = new Intent(Intent.ACTION_SEND);
        shareIntent.putExtra(Intent.EXTRA_TITLE, argsMap.get("filename"));
        shareIntent.putExtra(Intent.EXTRA_STREAM, shareContentUri);
        shareIntent.setType(argsMap.get("mimeType"));
        shareIntent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);


        context.startActivity(Intent.createChooser(shareIntent, argsMap.get("subject")));
    }
}
