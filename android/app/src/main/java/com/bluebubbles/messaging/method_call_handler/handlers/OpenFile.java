package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import androidx.core.content.FileProvider;

import java.io.File;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class OpenFile implements Handler{
    public static String TAG = "open_file";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public OpenFile(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        Intent intent = new Intent(Intent.ACTION_VIEW);
        Log.d("filesDir", "filesDir is " + context.getFilesDir().getAbsolutePath() + (String) call.argument("path"));
        Uri data = FileProvider.getUriForFile(context, "com.bluebubbles.messaging.fileprovider", new File(context.getFilesDir().getAbsolutePath() + (String) call.argument("path")));
        context.grantUriPermission(context.getPackageName(), data, Intent.FLAG_GRANT_READ_URI_PERMISSION);
        intent.setDataAndType(data, (String) call.argument("mimeType"));
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        context.startActivity(intent);

        result.success("");
    }
}
