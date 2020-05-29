package com.example.bluebubble_messages;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.util.Log;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
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
                            } else if(call.method.equals("create-notif-channel")) {
                                createNotificationChannel(call.argument("channel_name"), call.argument("channel_description"), call.argument("CHANNEL_ID"));
                                result.success("");
                            } else if(call.method.equals("new-message-notification"))    {
                                Intent intent = new Intent(this, MainActivity.class);
                                intent.setType("NotificationOpen");
                                intent.putExtra("id", call.argument("notificationId").toString());
                                PendingIntent pendingIntent = PendingIntent.getActivity(MainActivity.this, 0, intent, Intent.FILL_IN_ACTION);
                                NotificationCompat.Builder builder = new NotificationCompat.Builder(this, call.argument("CHANNEL_ID"))
                                        .setSmallIcon(R.mipmap.ic_launcher)
                                        .setContentTitle(call.argument("contentTitle"))
                                        .setContentText(call.argument("contentText"))
//                                        .setLargeIcon()
                                        .setAutoCancel(true)
                                        .setContentIntent(pendingIntent)
                                        .setGroup(call.argument("group"));
                                NotificationManagerCompat notificationManager = NotificationManagerCompat.from(getContext());
                                notificationManager.notify(call.argument("notificationId"), builder.build());
                                result.success("");
                            } else {
                                result.notImplemented();
                            }
                        }
                );
    }


    //for notifications
    private void createNotificationChannel(String channel_name, String channel_description, String CHANNEL_ID) {
        // Create the NotificationChannel, but only on API 26+ because
        // the NotificationChannel class is new and not in the support library
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            CharSequence name = channel_name;
            String description = channel_description;
            int importance = NotificationManager.IMPORTANCE_HIGH;
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, name, importance);
            channel.setDescription(description);
            // Register the channel with the system; you can't change the importance
            // or other notification behaviors after this
            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            notificationManager.createNotificationChannel(channel);
        }
    }

    protected void onNewIntent(Intent intent) {
        if(intent == null || intent.getType() == null) return;
        if(intent.getType().equals("NotificationOpen")) {
            Log.d("Notifications",  "tapped on notification by id " +intent.getExtras().getString("id"));
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL) .invokeMethod("ChatOpen", intent.getExtras().getString("id"));
        }
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
