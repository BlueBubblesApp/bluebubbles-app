package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.content.Intent;
import android.provider.MediaStore;

import com.bluebubbles.messaging.MainActivity;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static com.bluebubbles.messaging.MainActivity.PICK_IMAGE;

import java.util.ArrayList;

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
        String[] mimetypes = {"image/*", "video/*", "file/*", "audio/*", "application/*", "text/*"};
        if (call.argument("mimeTypes") != null) {
            final ArrayList<String> mimeTypes = call.argument("mimeTypes");
            mimetypes = (String[]) mimeTypes.toArray(new String[mimeTypes.size()]);
        }
        boolean allowMultiple = false;
        if (call.argument("allowMultiple") != null) {
            allowMultiple = (Boolean) call.argument("allowMultiple");
        }

        Intent getIntent  = new Intent(Intent.ACTION_GET_CONTENT);
        getIntent.setType("*/*");
        getIntent.putExtra(Intent.EXTRA_MIME_TYPES, mimetypes);
        getIntent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple);

        Intent pickIntent = new Intent(Intent.ACTION_PICK, android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
        pickIntent.setType("*/*");
        pickIntent.putExtra(Intent.EXTRA_MIME_TYPES, mimetypes);
        pickIntent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple);

        Intent chooserIntent = Intent.createChooser(getIntent, "Select Files");
        chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, new Intent[] {pickIntent});

        try {
            MainActivity activity = (MainActivity) context;
            activity.result = result;
            activity.startActivityForResult(chooserIntent, PICK_IMAGE);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
