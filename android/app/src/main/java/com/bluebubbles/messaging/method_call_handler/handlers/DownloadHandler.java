package com.bluebubbles.messaging.method_call_handler.handlers;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import android.content.Context;
import android.os.Build;
import androidx.annotation.RequiresApi;
import android.util.Log;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.Base64;

public class DownloadHandler implements Handler {
    public static String TAG = "download-file";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public DownloadHandler(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    public void Handle() {
        final byte[] decoded = Base64.getDecoder().decode(call.argument("data").toString());
        Runnable r = new Runnable() {
            @Override
            public void run() {
                try {
                    File outputFile = new File(call.argument("path").toString());
                    if (!outputFile.exists()) {
                        outputFile.getParentFile().mkdirs();
                        outputFile.createNewFile();
                    }
                    Files.write(Paths.get(call.argument("path").toString()), decoded, StandardOpenOption.APPEND);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        };

        Thread t = new Thread(r);
        t.start();
        result.success("");
    }
}
