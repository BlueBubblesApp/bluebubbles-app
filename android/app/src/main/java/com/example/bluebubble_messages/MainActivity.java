package com.example.bluebubble_messages;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.util.Log;

import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.iid.FirebaseInstanceId;
import com.google.firebase.iid.InstanceIdResult;



public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "samples.flutter.dev/fcm";
    private static final String TAG = "MainActivity";
    FirebaseApp app;
    FlutterEngine engine;


    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        engine = flutterEngine;
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("auth")) {
                                if (app == null) {
                                    app = FirebaseApp.initializeApp(getContext(), new FirebaseOptions.Builder()
                                            .setProjectId(call.argument("project_id"))
                                            .setStorageBucket(call.argument("storage_bucket"))
                                            .setApiKey(call.argument("api_key"))
                                            .setDatabaseUrl(call.argument("firebase_url"))
                                            .setGcmSenderId(call.argument("client_id"))
                                            .setApplicationId(call.argument("application_id"))
                                            .build());
                                }
                                FirebaseInstanceId.getInstance(app).getInstanceId()
                                        .addOnCompleteListener(new OnCompleteListener<InstanceIdResult>() {
                                            @Override
                                            public void onComplete(@NonNull Task<InstanceIdResult> task) {
                                                if (!task.isSuccessful()) {
                                                    Log.d("FCM", "getInstanceId failed", task.getException());
                                                    result.error("Failed to authenticate", "getInstanceId failed", task.getException());
                                                } else {

                                                    String token = task.getResult().getToken();
                                                    Log.d("FCM", "token: " + token);
                                                    result.success(token);
                                                }
                                            }
                                        });
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }

    @Override
    protected void onStart() {
        super.onStart();
        LocalBroadcastManager.getInstance(this).registerReceiver((mMessageReceiver),
                new IntentFilter("MyData")
        );
    }

    private BroadcastReceiver mMessageReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod(intent.getExtras().getString("type"), intent.getExtras().getString("data"));
        }
    };
}
