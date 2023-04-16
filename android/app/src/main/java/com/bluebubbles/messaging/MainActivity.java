package com.bluebubbles.messaging;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import android.annotation.SuppressLint;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ClipData;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.PersistableBundle;
import android.provider.OpenableColumns;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.content.pm.ShortcutInfoCompat;
import androidx.core.content.pm.ShortcutManagerCompat;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import androidx.work.WorkManager;

import com.bluebubbles.messaging.method_call_handler.MethodCallHandler;
import com.bluebubbles.messaging.sharing.ShareShortcutManager;

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

public class MainActivity extends FlutterFragmentActivity {
    public static final String CHANNEL = "com.bluebubbles.messaging";
    private static final String TAG = "MainActivity";
    public static FlutterEngine engine;
    public static int NOTIFICATION_SETTINGS = 1000;
    public MethodChannel.Result result = null;

    @RequiresApi(api = Build.VERSION_CODES.M)
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
                .setMethodCallHandler(((call, result) -> MethodCallHandler.methodCallHandler(call, result, MainActivity.this, null)));
    }

    // Used during the result after file picking
    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == NOTIFICATION_SETTINGS) {
            result.success(null);
        }
        super.onActivityResult(requestCode, resultCode, data);
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
        Log.d(TAG, "Removing Activity from memory");
        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("remove-sendPort", null);
        engine = null;
        super.onDestroy();
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    @Override
    protected void onStop() {
        Log.d(TAG, "Stopping Activity (isFinishing: " + isFinishing() + ")");
        super.onStop();
    }

    private BroadcastReceiver mMessageReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            String type = intent.getExtras().getString("type");
            Log.d(TAG, "Received intent type " + type);
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod(type, intent.getExtras().getString("data"));
        }
    };
}
