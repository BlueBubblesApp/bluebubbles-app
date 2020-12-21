package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.content.Intent;
import android.provider.MediaStore;

import com.bluebubbles.messaging.MainActivity;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static com.bluebubbles.messaging.MainActivity.PICK_IMAGE;

public class PickFile implements Handler{
    public static String TAG = "pick-file";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public PickFile(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        Intent intent  = new Intent(Intent.ACTION_GET_CONTENT);
        intent.setType("*/*");
        try {
            MainActivity activity = (MainActivity) context;
            activity.result = result;
            activity.startActivityForResult(intent, PICK_IMAGE);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
