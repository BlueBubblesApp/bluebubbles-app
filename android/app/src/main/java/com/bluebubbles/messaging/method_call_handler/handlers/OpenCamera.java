package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.provider.MediaStore;

import androidx.core.content.FileProvider;

import com.bluebubbles.messaging.MainActivity;

import java.io.File;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static com.bluebubbles.messaging.MainActivity.OPEN_CAMERA;


public class OpenCamera implements Handler{

    public static String TAG = "open-camera";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;


    public OpenCamera(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        String cameraType = MediaStore.ACTION_IMAGE_CAPTURE;
        if (call.argument("type").equals("video")) {
            cameraType = MediaStore.ACTION_VIDEO_CAPTURE;
        }

        Intent intent = new Intent(cameraType);
        try {
            File file = new File((String) call.argument("path"));
            if(!file.exists()) {
                result.error("NO FILE FOUND", "Failed to find file", "");
                return;
            }

            Uri outputURI = FileProvider.getUriForFile(context, "com.bluebubbles.messaging.fileprovider", file);
            intent.putExtra(MediaStore.EXTRA_OUTPUT, outputURI);

            MainActivity activity = (MainActivity) context;
            activity.result = result;
            activity.startActivityForResult(intent, OPEN_CAMERA);
        } catch (Exception e) {
            e.printStackTrace();
            result.error("FAILED TO OPEN CAMERA", "Failed to start activity", e.getMessage());
        }
    }
}
