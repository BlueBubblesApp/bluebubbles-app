package com.bluebubbles.messaging;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import android.annotation.SuppressLint;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.PersistableBundle;
import android.provider.OpenableColumns;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import androidx.work.WorkManager;

import com.bluebubbles.messaging.method_call_handler.MethodCallHandler;
import com.bluebubbles.messaging.sharing.ShareShortcutManager;
import com.itsclicking.clickapp.fluttersocketio.SocketIOManager;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;


public class MainActivity extends FlutterActivity {
    public static final String CHANNEL = "com.bluebubbles.messaging";
    private static final String TAG = "MainActivity";
    public static FlutterEngine engine;
    private String startingChat;

    public static int PICK_IMAGE = 1000;
    public MethodChannel.Result result = null;


    @Override
    public void onCreate(@Nullable Bundle savedInstanceState, @Nullable PersistableBundle persistentState) {
        super.onCreate(savedInstanceState, persistentState);
        ShareShortcutManager.publishShareTarget(getApplicationContext());
    }


    @SuppressLint("RestrictedApi")
    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        engine = flutterEngine;

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(((call, result) -> MethodCallHandler.methodCallHandler(call, result, MainActivity.this, null)));
    }


    protected void onNewIntent(Intent intent) {
        // Get intent, action and MIME type
        String action = intent.getAction();
        String type = intent.getType();
        if (type == null) return;

        if (Intent.ACTION_SEND.equals(action)) {
            if ("text/plain".equals(type)) {
                handleSendText(intent); // Handle text being sent
            } else {
                handleShareFile(intent);
            }
        } else if (Intent.ACTION_SEND_MULTIPLE.equals(action) && type != null) {
            handleSendMultipleImages(intent);
        } else {
            if (type.equals("NotificationOpen")) {
                Log.d("Notifications", "tapped on notification by id " + intent.getExtras().getInt("id"));
                startingChat = intent.getStringExtra("chatGUID");


                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("ChatOpen", intent.getExtras().getString("chatGUID"));
            }
        }

    }

    // Used during the result after file picking
    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == PICK_IMAGE) {

            if (resultCode == RESULT_OK) {
                File file = new File(getApplicationContext().getFilesDir().getAbsolutePath() + "/sharedFiles/" + getFileName(data.getData()));
                try {
                    file.createNewFile();
                    writeBytesFromURI(data.getData(), file);
                    if (result != null) {
                        result.success(file.getAbsolutePath());
                        Log.d("PICK_FILE", "Result is okay! " + file.getAbsolutePath());
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }

            } else {
                Log.d("PICK_FILE", "Something went wrong");
                result.success(null);
            }
            result = null;
        }
    }


    void handleSendText(Intent intent) {
        String sharedText = intent.getStringExtra(Intent.EXTRA_TEXT);
        if (sharedText != null) {
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("shareText", sharedText);
        }
    }

    void handleShareFile(Intent intent) {
        List<String> images = new ArrayList<>();
        Uri imageUri = (Uri) intent.getParcelableExtra(Intent.EXTRA_STREAM);
        if (imageUri != null) {
            try {
                File filesDir = new File(getFilesDir().getPath() + "/sharedFiles/");
                if (!filesDir.exists()) {
                    filesDir.mkdir();
                }
                File file = new File(getFilesDir().getPath() + "/sharedFiles/" + getFileName(imageUri));
                file.createNewFile();
                writeBytesFromURI(imageUri, file);
                images.add(file.getPath());
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("shareAttachments", images);
            } catch (Exception e) {

            }
        }
    }

    public void writeBytesFromURI(Uri contentUri, File file) {
        final int buffer_size = 4096;
        try {
            InputStream inputStream = getContentResolver().openInputStream(contentUri);
            BufferedOutputStream outputStream = new BufferedOutputStream(new FileOutputStream(file));
            byte[] bytes = new byte[buffer_size];
            for (int count = 0, prog = 0; count != -1; ) {
                count = inputStream.read(bytes);
                if (count != -1) {
                    outputStream.write(bytes, 0, count);
                    prog = prog + count;
                }
            }
            outputStream.flush();
            inputStream.close();
            outputStream.close();
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public String getFileName(Uri uri) {
        String result = null;
        if (uri.getScheme().equals("content")) {
            Cursor cursor = getContentResolver().query(uri, null, null, null, null);
            try {
                if (cursor != null && cursor.moveToFirst()) {
                    result = cursor.getString(cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME));
                }
            } finally {
                cursor.close();
            }
        }
        if (result == null) {
            result = uri.getPath();
            int cut = result.lastIndexOf('/');
            if (cut != -1) {
                result = result.substring(cut + 1);
            }
        }
        return result;
    }

    void handleSendMultipleImages(Intent intent) {
        ArrayList<Uri> imageUris = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
        List<String> images = new ArrayList<>();
        File filesDir = new File(getFilesDir().getPath() + "/sharedFiles/");
        if (!filesDir.exists()) {
            filesDir.mkdir();
        }
        if (imageUris != null) {
            for (Uri imageUri : imageUris) {
                try {
                    File file = new File(getFilesDir().getPath() + "/sharedFiles/" + getFileName(imageUri));
                    file.createNewFile();
                    images.add(file.getPath());
                    writeBytesFromURI(imageUri, file);
                } catch (Exception e) {
                    Log.d("share", "FAILURE");
                    e.printStackTrace();
                }
            }
            Log.d("share", images.toString());
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("shareAttachments", images);
        }
    }


    @Override
    protected void onStart() {
        super.onStart();
        LocalBroadcastManager.getInstance(this).registerReceiver(mMessageReceiver, new IntentFilter("MyData"));
        WorkManager.getInstance(getApplicationContext()).cancelAllWork();
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    protected void onDestroy() {
        Log.d("MainActivity", "removed from memory");
        SocketIOManager.getInstance().destroyAllSockets();
        engine = null;
        super.onDestroy();
    }

    private BroadcastReceiver mMessageReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            Log.d("notification", "on receive");
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod(intent.getExtras().getString("type"), intent.getExtras().getString("data"));
        }
    };


}
