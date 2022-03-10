package com.bluebubbles.messaging.method_call_handler.handlers;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import android.content.Context;
import android.os.Build;
import androidx.annotation.RequiresApi;
import android.util.Log;

import java.io.File;
import java.io.IOException;
import java.io.FileOutputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import android.util.Base64;

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
        final byte[] data = call.argument("data");
        if (data == null) {
            result.error("1", "Attachment data was null, no data to decode!", null);
            return;
        }

        if (data == null || data.length == 0) {
            result.success("");
            return;
        }

        Runnable r = new Runnable() {
            @Override
            public void run() {
                try {
                    File outputFile = new File(call.argument("path").toString());
                    if (!outputFile.exists()) {
                        outputFile.getParentFile().mkdirs();
                        outputFile.createNewFile();
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Files.write(Paths.get(call.argument("path").toString()), data, StandardOpenOption.APPEND);
                    } else {
                        FileOutputStream stream = new FileOutputStream(outputFile);
                        try {
                            stream.write(data);
                        } finally {
                            stream.close();
                        }
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
                result.success("");
            }
        };

        Thread t = new Thread(r);
        t.start();
    }
}
