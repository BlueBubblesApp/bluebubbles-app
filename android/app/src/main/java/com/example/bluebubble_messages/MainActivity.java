package com.example.bluebubble_messages;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Person;
import android.app.RemoteInput;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.Icon;
import android.location.Location;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.IBinder;
import android.os.PersistableBundle;
import android.preference.PreferenceManager;
import android.provider.ContactsContract;
import android.provider.MediaStore;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.database.ChildEventListener;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;
import com.google.firebase.iid.FirebaseInstanceId;
import com.google.firebase.iid.InstanceIdResult;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.judemanutd.autostarter.AutoStartPermissionHelper;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

import static com.example.bluebubble_messages.BackgroundService.app;
import static com.example.bluebubble_messages.BackgroundService.db;


public class MainActivity extends FlutterActivity {
    public static final String CHANNEL = "samples.flutter.dev/fcm";
    private static final String TAG = "MainActivity";
    static FlutterEngine engine;
    private FusedLocationProviderClient fusedLocationClient;
    private String startingChat;
    Map<Integer, NotificationCompat.Builder> progressBars = new HashMap<>();
    public static String BACKGROUND_SERVICE_SHARED_PREF = "BACKGROUND_SERVICE_SHARED_PREF ";
    public static String BACKGROUND_HANDLE_SHARED_PREF_KEY = "BACKGROUND_HANDLE_SHARED_PREF_KEY";


    @Override
    public void onCreate(@Nullable Bundle savedInstanceState, @Nullable PersistableBundle persistentState) {
        super.onCreate(savedInstanceState, persistentState);
    }

    private ValueEventListener dbListener = new ValueEventListener() {
        @Override
        public void onDataChange(@NonNull DataSnapshot dataSnapshot) {
            Log.d("firebase", "data changed");
            String serverURL = dataSnapshot.child("config").child("serverUrl").getValue().toString();
            Log.d("firebase", "new server: " + serverURL);
            if (engine != null) {
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("new-server", "[" + serverURL + "]");
            }
        }

        @Override
        public void onCancelled(@NonNull DatabaseError databaseError) {

        }
    };

    @SuppressLint("RestrictedApi")
    @RequiresApi(api = Build.VERSION_CODES.M)
    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        engine = flutterEngine;

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(((call, result) -> methodCallHandler(call, result, MainActivity.this, dbListener, fusedLocationClient)));
    }

    @SuppressLint("RestrictedApi")
    @RequiresApi(api = Build.VERSION_CODES.M)
    public static void methodCallHandler(MethodCall call, MethodChannel.Result result, Context context, ValueEventListener dbListener, FusedLocationProviderClient fusedLocationClient) {
        if (call.method.equals("auth")) {
            if (!isNetworkAvailable(context))
                result.error("no_internet", "No internet, retry in 10 seconds", "");
            if (app == null) {
                app = FirebaseApp.initializeApp(context, new FirebaseOptions.Builder()
                        .setProjectId(call.argument("project_id"))
                        .setStorageBucket(call.argument("storage_bucket"))
                        .setApiKey(call.argument("api_key"))
                        .setDatabaseUrl(call.argument("firebase_url"))
                        .setGcmSenderId(call.argument("client_id"))
                        .setApplicationId(call.argument("application_id"))
                        .build());
            }
            if (app == null) {
                result.error("could_not_initialize", "Failed to initialize, app == null", "");
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
            db = FirebaseDatabase.getInstance(app).getReference();
            try {
                db.removeEventListener(dbListener);
            } catch (Exception e) {

            }
            db.addValueEventListener(dbListener);
        } else if (call.method.equals("create-notif-channel")) {
            createNotificationChannel(call.argument("channel_name"), call.argument("channel_description"), call.argument("CHANNEL_ID"), context);
            result.success("");
        } else if (call.method.equals("new-message-notification")) {

            NotificationCompat.MessagingStyle style = null;
            NotificationManager notificationManager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
            int existingNotificationId = 0;
            for (StatusBarNotification notification : notificationManager.getActiveNotifications()) {
                String chatGuid = notification.getNotification().extras.getString("chatGuid");

                if (chatGuid != null && chatGuid.equals(call.argument("group"))) {
                    existingNotificationId = notification.getId();
                    style = NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(notification.getNotification());
                    break;
                }
            }

            if (style == null) {

                style = new NotificationCompat.MessagingStyle(androidx.core.app.Person.fromAndroidPerson(new Person.Builder().setName("some user").build()));
                style.setConversationTitle(call.argument("contentTitle"));
                style.setGroupConversation(call.argument("groupConversation"));
            }
            Long timestamp;
            if (call.argument("timeStamp").getClass() == Long.class) {
                timestamp = call.argument("timeStamp");
            } else if (call.argument("timeStamp").getClass() == Integer.class) {
                timestamp = Long.valueOf(((Integer) call.argument("timeStamp")).longValue());
            } else {
                timestamp = Long.valueOf(call.argument("timeStamp"));
            }
            Icon icon = null;
            if (call.argument("contactIcon") != null) {
                Bitmap bmp = BitmapFactory.decodeByteArray((byte[]) call.argument("contactIcon"), 0, ((byte[]) call.argument("contactIcon")).length);
                icon = Icon.createWithBitmap(bmp);
            }
            Person.Builder person = new Person.Builder().setName(call.argument("name"));
            if (icon != null) {
                person.setIcon(icon);
            }
            style.addMessage(new NotificationCompat.MessagingStyle.Message(
                    call.argument("contentText"),
                    timestamp,
                    androidx.core.app.Person.fromAndroidPerson(person.build())
            ));
            Bundle extras = new Bundle();
            extras.putCharSequence("chatGuid", call.argument("group"));

            if (existingNotificationId == 0) {
                existingNotificationId = call.argument("notificationId");
            }

            //occurs when clicking on the notification
            PendingIntent openIntent = PendingIntent.getActivity(
                    context,
                    existingNotificationId,
                    new Intent(context, MainActivity.class)
                            .putExtra("id", existingNotificationId)
                            .putExtra("chatGUID",
                                    (String) call.argument("group")).setType("NotificationOpen"),
                    Intent.FILL_IN_ACTION);

            //for the dismiss button
            PendingIntent dismissIntent = PendingIntent.getBroadcast(
                    context,
                    existingNotificationId,
                    new Intent(context, ReplyReceiver.class)
                            .putExtra("id", existingNotificationId)
                            .putExtra("chatGuid",
                                    (String) call.argument("group")).setType("markAsRead"),
                    PendingIntent.FLAG_UPDATE_CURRENT);
            NotificationCompat.Action dismissAction = new NotificationCompat.Action.Builder(0, "Mark As Read", dismissIntent).build();

            //for the quick reply
            Intent intent = new Intent(context, ReplyReceiver.class)
                    .putExtra("id", existingNotificationId)
                    .putExtra("chatGuid", (String) call.argument("group"))
                    .setType("reply");
            PendingIntent replyIntent = PendingIntent.getBroadcast(context, existingNotificationId, intent, PendingIntent.FLAG_UPDATE_CURRENT);
            androidx.core.app.RemoteInput replyInput = new androidx.core.app.RemoteInput.Builder("key_text_reply").setLabel("Reply").build();
            NotificationCompat.Action replyAction = new NotificationCompat.Action.Builder(0, "Reply", replyIntent).addRemoteInput(replyInput).build();

            //actual notification
            NotificationCompat.Builder builder = new NotificationCompat.Builder(context, call.argument("CHANNEL_ID"))
                    .setSmallIcon(R.mipmap.ic_stat_icon)
                    .setContentTitle(call.argument("contentTitle"))
                    .setContentText(call.argument("contentText"))
                    .setAutoCancel(true)
                    .setContentIntent(openIntent)
                    .addAction(dismissAction)
                    .addAction(replyAction)
                    .setStyle(style)
                    .addExtras(extras)
                    .setColor(4888294);
//                                        .setGroup("new-messages");
//                                        .setGroup("messageGroup");
//                                NotificationCompat.Builder summaryBuilder = new NotificationCompat.Builder(this, call.argument("CHANNEL_ID"))
//                                        .setSmallIcon(R.mipmap.ic_launcher)
//                                        .setContentTitle("New messages")
//                                        .setGroup(call.argument("new-messages"))
//                                        .setAutoCancel(true)
//                                        .setContentIntent(openIntent)
//                                        .setGroupSummary(true);

            NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);

            notificationManagerCompat.notify(existingNotificationId, builder.build());
            Log.d("here", "here");
//                                notificationManagerCompat.notify(call.argument("summaryId"), summaryBuilder.build());
            result.success("");
        } else if (call.method.equals("create-socket-issue-warning")) {
            NotificationCompat.Builder builder = new NotificationCompat.Builder(context, call.argument("CHANNEL_ID"))
                    .setSmallIcon(R.mipmap.ic_stat_icon)
                    .setContentTitle("Could not connect")
                    .setContentText("Your server may be offline")
                    .setColor(4888294)
                    .setAutoCancel(true);
            NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);
            notificationManagerCompat.notify(1000, builder.build());
            result.success("");
        } else if (call.method.equals("clear-socket-issue")) {
            NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);
            notificationManagerCompat.cancel(1000);
        } else if (call.method.equals("open_file")) {
            Intent intent = new Intent(Intent.ACTION_VIEW);
            Log.d("filesDir", "filesDir is " + context.getFilesDir().getAbsolutePath() + (String) call.argument("path"));
            Uri data = FileProvider.getUriForFile(context, "com.example.path_provider", new File(context.getFilesDir().getAbsolutePath() + (String) call.argument("path")));
            context.grantUriPermission(context.getPackageName(), data, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            intent.setDataAndType(data, (String) call.argument("mimeType"));
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            context.startActivity(intent);

            result.success("");
        } else if (call.method.equals("open-link")) {
            context.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(call.argument("link"))));
            result.success("");
        } else if (call.method.equals("clear-chat-notifs")) {
            NotificationManager manager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
            for (StatusBarNotification statusBarNotification : manager.getActiveNotifications()) {
                if (statusBarNotification.getNotification().extras.getString("chatGuid") != null && statusBarNotification.getNotification().extras.getString("chatGuid").contains(Objects.requireNonNull(call.argument("chatGuid")))) {
                    NotificationManagerCompat.from(context).cancel(statusBarNotification.getId());
                } else {
                    Log.d("notification clearing", statusBarNotification.getGroupKey());
                }
            }
            result.success("");
        } else if (call.method.equals("get-last-location")) {
            if (fusedLocationClient == null)
                fusedLocationClient = LocationServices.getFusedLocationProviderClient(context);
            fusedLocationClient.getLastLocation()
                    .addOnSuccessListener((Activity) context, new OnSuccessListener<Location>() {
                        @Override
                        public void onSuccess(Location location) {
                            // Got last known location. In some rare situations this can be null.
                            if (location != null) {
                                // Logic to handle location object
                                Map<String, Double> latlng = new HashMap<String, Double>();
                                latlng.put("longitude", location.getLongitude());
                                latlng.put("latitude", location.getLatitude());
                                Log.d("Location", "Location retreived " + latlng.toString());
                                result.success(latlng);
                            } else {
                                Log.d("Location", "unable to retreive location");
                                result.success(null);
                            }
                        }
                    });

        } else if (call.method.equals("save-image-to-album")) {
//                                File storageDir = new File(
//                                        Environment.getExternalStoragePublicDirectory(
//                                                Environment.DIRECTORY_PICTURES
//                                        ),
//
//
//                                );
            Intent mediaScanIntent = new Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE);
            File f = new File((String) call.argument("path"));
            Uri contentUri = Uri.fromFile(f);
            mediaScanIntent.setData(contentUri);
            context.sendBroadcast(mediaScanIntent);
            result.success("");
        } else if (call.method.equals("get-starting-intent")) {
            result.success(((MainActivity) context).getIntent().getStringExtra("chatGUID"));

        } else if (call.method.equals("initialize-background-handle")) {
            Log.d("handle", "initialize background handle: " + call.argument("handle").getClass().toString());
            Long callbackHandle;
            if (call.argument("handle").getClass() == Long.class) {
                callbackHandle = call.argument("handle");
            } else if (call.argument("handle").getClass() == Integer.class) {
                callbackHandle = Long.valueOf(((Integer) call.argument("handle")).longValue());
            } else {
                callbackHandle = Long.valueOf(call.argument("handle"));
            }

            context.getSharedPreferences(BACKGROUND_SERVICE_SHARED_PREF, Context.MODE_PRIVATE)
                    .edit()
                    .putLong(BACKGROUND_HANDLE_SHARED_PREF_KEY, callbackHandle)
                    .apply();
            result.success("");
        } else {
            result.notImplemented();
        }
    }


    //for notifications
    public static void createNotificationChannel(String channel_name, String channel_description, String CHANNEL_ID, Context context) {
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
            NotificationManager notificationManager = context.getSystemService(NotificationManager.class);
            notificationManager.createNotificationChannel(channel);
        }
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
            }
        } else if (Intent.ACTION_SEND_MULTIPLE.equals(action) && type != null) {
            if (type.startsWith("image/")) {
                handleSendMultipleImages(intent); // Handle multiple images being sent
            } else if (type.startsWith("video/")) {
                handleSendMultipleImages(intent);
            }
        } else {
            if (type.equals("NotificationOpen")) {
                Log.d("Notifications", "tapped on notification by id " + intent.getExtras().getInt("id"));
//                startingIntent = intent;
                startingChat = intent.getStringExtra("chatGUID");


                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("ChatOpen", intent.getExtras().getString("chatGUID"));
            }
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
        ArrayList<String> imagePaths = new ArrayList<String>();
        Uri imageUri = (Uri) intent.getParcelableExtra(Intent.EXTRA_STREAM);
        if (imageUri != null) {
            imagePaths.add(getRealPathFromURI(imageUri));
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("shareAttachments", imagePaths);
            // Update UI to reflect image being shared
        }
    }

    public String getRealPathFromURI(Uri contentUri) {
        String[] proj = {MediaStore.Audio.Media.DATA};
        Cursor cursor = managedQuery(contentUri, proj, null, null, null);
        int column_index = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA);
        cursor.moveToFirst();
        return cursor.getString(column_index);
    }

    void handleSendMultipleImages(Intent intent) {
        ArrayList<Uri> imageUris = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
        ArrayList<String> imagePaths = new ArrayList<String>();
        if (imageUris != null) {
            for (Uri imageUri : imageUris) {
                imagePaths.add(getRealPathFromURI(imageUri));
            }
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("shareAttachments", imagePaths);
            // Update UI to reflect multiple images being shared
        }
    }


    BackgroundService backgroundService;

    protected ServiceConnection mServerConn = new ServiceConnection() {
        @RequiresApi(api = Build.VERSION_CODES.M)
        @Override
        public void onServiceConnected(ComponentName name, IBinder binder) {
            backgroundService = ((BackgroundService.LocalBinder) binder).getService();
            backgroundService.setAlive(true);
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            backgroundService = null;
        }
    };

    @Override
    protected void onStart() {
        super.onStart();
        LocalBroadcastManager.getInstance(this).registerReceiver(mMessageReceiver, new IntentFilter("MyData"));
        getApplicationContext().bindService(new Intent(getApplicationContext(), BackgroundService.class), mServerConn, Context.BIND_AUTO_CREATE);
        Intent serviceIntent = new Intent(getApplicationContext(), BackgroundService.class);
        serviceIntent.putExtra("fromBackground", false);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent);
        } else {
            startService(serviceIntent);
        }
//        startService(serviceIntent);
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    @Override
    protected void onDestroy() {
        Log.d("MainActivity", "removed from memory");
        if (backgroundService != null && backgroundService.isAlive()) {
            backgroundService.setAlive(false);
            Log.d("isAlive", "set isAlive to false");
        }
        try {
            getApplicationContext().unbindService(mServerConn);
            LocalBroadcastManager.getInstance(this).unregisterReceiver(mMessageReceiver);
        } catch (Exception e) {
            e.printStackTrace();
            Log.d("isolate", "unable to unbind service");

        }
        super.onDestroy();
    }

    private BroadcastReceiver mMessageReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            Log.d("notification", "on receive");
            new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod(intent.getExtras().getString("type"), intent.getExtras().getString("data"));
        }
    };

    private static boolean isNetworkAvailable(Context context) {
        ConnectivityManager connectivityManager
                = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
        return activeNetworkInfo != null && activeNetworkInfo.isConnected();
    }
}
