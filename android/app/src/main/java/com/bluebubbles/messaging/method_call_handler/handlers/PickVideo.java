package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.content.Intent;
import android.provider.MediaStore;

import com.bluebubbles.messaging.MainActivity;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static com.bluebubbles.messaging.MainActivity.PICK_IMAGE;

public class PickVideo implements Handler{
    public static String TAG = "pick-video";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public PickVideo(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        Intent getIntent = new Intent(Intent.ACTION_GET_CONTENT);
        getIntent.setType("video/*");

        Intent pickIntent = new Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
        pickIntent.setType("video/*");

        Intent chooserIntent = Intent.createChooser(getIntent, "Select Video");
        chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, new Intent[]{pickIntent});


        try {
            MainActivity activity = (MainActivity) context;
            activity.result = result;
            activity.startActivityForResult(chooserIntent, PICK_IMAGE);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
