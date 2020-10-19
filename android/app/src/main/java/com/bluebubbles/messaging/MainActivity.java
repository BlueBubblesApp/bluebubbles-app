package com.bluebubbles.messaging;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import android.annotation.SuppressLint;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.IBinder;
import android.os.PersistableBundle;
import android.provider.OpenableColumns;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import androidx.work.WorkManager;

import com.bluebubbles.messaging.method_call_handler.MethodCallHandler;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.itsclicking.clickapp.fluttersocketio.SocketIOManager;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;


public class MainActivity extends FlutterActivity {
    public static final String CHANNEL = "com.bluebubbles.messaging";
    private static final String TAG = "MainActivity";
    public static FlutterEngine engine;
    private FusedLocationProviderClient fusedLocationClient;
    private String startingChat;
    Map<Integer, NotificationCompat.Builder> progressBars = new HashMap<>();

    public static int PICK_IMAGE = 1000;
    public MethodChannel.Result result = null;


    @Override
    public void onCreate(@Nullable Bundle savedInstanceState, @Nullable PersistableBundle persistentState) {
        super.onCreate(savedInstanceState, persistentState);
    }


    @SuppressLint("RestrictedApi")
    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        engine = flutterEngine;

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(((call, result) -> MethodCallHandler.methodCallHandler(call, result, MainActivity.this,  fusedLocationClient, null)));
    }




    protected void onNewIntent(Intent intent) {
        // Get intent, action and MIME type
        String action = intent.getAction();
        String type = intent.getType();
        if (type == null) return;

        if (Intent.ACTION_SEND.equals(action)) {
            if ("text/plain".equals(type)) {
                handleSendText(intent); // Handle text being sent
            } else if (type.startsWith("image/")) {
                handleSendImage(intent); // Handle single image being sent
            } else if (type.startsWith("video/")) {
                handleSendImage(intent);
            } else {
                Log.d("ShareImage", "type not found " + type);
            }
        } else if (Intent.ACTION_SEND_MULTIPLE.equals(action) && type != null) {
            if (type.startsWith("image/")) {
                handleSendMultipleImages(intent); // Handle multiple images being sent
            } else if (type.startsWith("video/")) {
                handleSendMultipleImages(intent);
            } else {
                Log.d("ShareImage", "type not found " + type);
            }
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
                    Files.write(Paths.get(file.getAbsolutePath()), getBytesFromUri(data.getData()));
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
            // Update UI to reflect text being shared
        }
    }

    void handleSendImage(Intent intent) {
        Map<String, byte[]> imagePaths = new HashMap<String, byte[]>();
        Uri imageUri = (Uri) intent.getParcelableExtra(Intent.EXTRA_STREAM);
        if (imageUri != null) {
            imagePaths.put(getFileName(imageUri), getBytesFromUri(imageUri));
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("shareAttachments", imagePaths);
            Log.d("ShareImage", imagePaths.toString());
        }
    }

    public byte[] getBytesFromUri(Uri contentUri) {
//        String[] proj = {MediaStore.Audio.Media.DATA};
//        Cursor cursor = getContentResolver().query(contentUri, proj, null, null, null);
//        int column_index = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA);
//        cursor.moveToFirst();
//        return cursor.getString(column_index);
        try {
            InputStream stream = getContentResolver().openInputStream(contentUri);
            byte[] bytes = new byte[stream.available()];
            stream.read(bytes);
            return bytes;
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
        return null;
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
        Map<String, byte[]> imagePaths = new HashMap<String, byte[]>();
        if (imageUris != null) {
            for (Uri imageUri : imageUris) {
                imagePaths.put(getFileName(imageUri), getBytesFromUri(imageUri));
            }
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("shareAttachments", imagePaths);
            Log.d("ShareImage", imagePaths.toString());
            // Update UI to reflect multiple images being shared
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
