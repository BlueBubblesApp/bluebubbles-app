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
import android.app.RemoteInput;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Build;
import android.os.Bundle;
import android.os.IBinder;
import android.preference.PreferenceManager;
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
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.judemanutd.autostarter.AutoStartPermissionHelper;


public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "samples.flutter.dev/fcm";
    private static final String TAG = "MainActivity";
    FirebaseApp app;
    public FlutterEngine engine;
    public Long callbackHandle;


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
                            } else if (call.method.equals("create-notif-channel")) {
                                createNotificationChannel(call.argument("channel_name"), call.argument("channel_description"), call.argument("CHANNEL_ID"));
                                result.success("");
                            } else if (call.method.equals("new-message-notification")) {
                                //occurs when clicking on the notification
                                PendingIntent openIntent = PendingIntent.getActivity(MainActivity.this, call.argument("notificationId"), new Intent(this, MainActivity.class).putExtra("id", (int) call.argument("notificationId")).putExtra("chatGUID", (String) call.argument("group")).setType("NotificationOpen"), Intent.FILL_IN_ACTION);

                                //for the dismiss button
                                PendingIntent dismissIntent = PendingIntent.getActivity(MainActivity.this, call.argument("notificationId"), new Intent(this, MainActivity.class).putExtra("id", (int) call.argument("notificationId")).setType("markAsRead"), PendingIntent.FLAG_UPDATE_CURRENT);
                                NotificationCompat.Action dismissAction = new NotificationCompat.Action.Builder(0, "Mark As Read", dismissIntent).build();

                                //for the quick reply
                                PendingIntent replyIntent = PendingIntent.getBroadcast(this, call.argument("notificationId"), new Intent(this, ReplyReceiver.class).putExtra("id", (int) call.argument("notificationId")).setType("reply"), PendingIntent.FLAG_UPDATE_CURRENT);
                                androidx.core.app.RemoteInput replyInput = new androidx.core.app.RemoteInput.Builder("key_text_reply").setLabel("Reply").build();
                                NotificationCompat.Action replyAction = new NotificationCompat.Action.Builder(0, "Reply", replyIntent).addRemoteInput(replyInput).build();

                                //actual notification
                                NotificationCompat.Builder builder = new NotificationCompat.Builder(this, call.argument("CHANNEL_ID"))
                                        .setSmallIcon(R.mipmap.ic_launcher)
                                        .setContentTitle(call.argument("contentTitle"))
                                        .setContentText(call.argument("contentText"))
                                        .setAutoCancel(true)
                                        .setContentIntent(openIntent)
                                        .addAction(dismissAction)
                                        .addAction(replyAction)
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
        if (intent == null || intent.getType() == null) return;
        if (intent.getType().equals("NotificationOpen")) {
            Log.d("Notifications", "tapped on notification by id " + intent.getExtras().getInt("id"));
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("ChatOpen", intent.getExtras().getString("chatGUID"));
        } else if (intent.getType().equals("reply")) {
        } else if (intent.getType().equals("markAsRead")) {
            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(getContext());
            notificationManager.cancel(intent.getExtras().getInt("id"));
        }
    }

    BackgroundService backgroundService;

    protected ServiceConnection mServerConn = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder binder) {
            backgroundService = ((BackgroundService.LocalBinder) binder).getService();
            backgroundService.isAlive = true;
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            backgroundService.isAlive = false;
            backgroundService = null;

            // Close the DB connection
            DatabaseHelper helper = DatabaseHelper.getInstance(getContext());
            helper.close();
        }
    };

    @Override
    protected void onStart() {
        super.onStart();
        LocalBroadcastManager.getInstance(this).registerReceiver(mMessageReceiver, new IntentFilter("MyData"));
        registerReceiver(replyReceiver, new IntentFilter("Reply"));
        getApplicationContext().bindService(new Intent(getApplicationContext(), BackgroundService.class), mServerConn, Context.BIND_AUTO_CREATE);
        Intent serviceIntent = new Intent(getApplicationContext(), BackgroundService.class);
        startService(serviceIntent);
    }

    @Override
    protected void onDestroy() {
        Log.d("MainActivity", "removed from memory");
//        unregisterReceiver(mMessageReceiver);
        try {
            getApplicationContext().unbindService(mServerConn);
        } catch (Exception e) {
            e.printStackTrace();
            Log.d("isolate", "unable to unbind service");

        }
//        if(backgroundService != null) {
//            backgroundService.unbindService(mServerConn);
//        }
        super.onDestroy();
    }

    private BroadcastReceiver mMessageReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent.getType() != null && intent.getType().equals("reply")) {
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("reply", intent.getExtras());
            } else {
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod(intent.getExtras().getString("type"), intent.getExtras().getString("data"));
            }
        }
    };

    private BroadcastReceiver replyReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            Log.d("Notification", "reply");
        }
    };
}
