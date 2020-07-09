package com.example.bluebubble_messages;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Binder;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import com.baseflow.permissionhandler.PermissionHandlerPlugin;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;
import com.google.firebase.iid.FirebaseInstanceId;
import com.google.firebase.iid.InstanceIdResult;
import com.itsclicking.clickapp.fluttersocketio.FlutterSocketIoPlugin;
import com.tekartik.sqflite.SqflitePlugin;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.ArrayList;
import java.util.Random;

import flutter.plugins.contactsservice.contactsservice.ContactsServicePlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugins.pathprovider.PathProviderPlugin;
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin;
import io.flutter.view.FlutterCallbackInformation;
import io.flutter.view.FlutterMain;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.FlutterRunArguments;

import static com.example.bluebubble_messages.MainActivity.CHANNEL;
import static com.example.bluebubble_messages.MainActivity.engine;

public class BackgroundService extends Service {
    // static boolean isRunning = false;
    private boolean isAlive = false;
    public static boolean backgroundServiceActive = false;
    private FlutterNativeView backgroundView;
    public static MethodChannel backgroundChannel;
    public static FirebaseApp app;

    public static DatabaseReference db;

    public boolean isAlive() {
        return isAlive;
    }

    public void setAlive(boolean val) {
        isAlive = val;
        if (!val) {
            initHeadlessThread();
        } else {
            destroyHeadlessThread();
        }
    }

    public void invokeMethod(String method, Object arguments) {
        if (backgroundChannel == null) {
            return;
        }
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                backgroundChannel.invokeMethod(method, arguments);
            }
        });
    }

    public void requestFirebaseAuth() {
        if(backgroundView != null && backgroundChannel != null) {
            backgroundChannel.invokeMethod("requestFCMAuth", "");
        }
    }

    private void initHeadlessThread() {
        if (backgroundView == null) {
            FlutterMain.ensureInitializationComplete(getApplicationContext(), null);

            Long callbackHandle = getApplicationContext().getSharedPreferences(MainActivity.BACKGROUND_SERVICE_SHARED_PREF, Context.MODE_PRIVATE).getLong(MainActivity.BACKGROUND_HANDLE_SHARED_PREF_KEY, 0);
            FlutterCallbackInformation callbackInformation = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle);

            new Handler(Looper.getMainLooper()).post(new Runnable() {
                @Override
                public void run() {
                    backgroundView = new FlutterNativeView(getApplicationContext(), true);
                    PluginRegistry registry = backgroundView.getPluginRegistry();
                    SqflitePlugin.registerWith(registry.registrarFor("com.tekartik.sqflite.SqflitePlugin"));
                    PathProviderPlugin.registerWith(registry.registrarFor("plugins.flutter.io/path_provider"));
                    FlutterSocketIoPlugin.registerWith(registry.registrarFor("flutter_socket_io"));
                    PermissionHandlerPlugin.registerWith(registry.registrarFor("flutter.baseflow.com/permissions/methods"));
                    ContactsServicePlugin.registerWith(registry.registrarFor("github.com/clovisnicolas/flutter_contacts"));
                    SharedPreferencesPlugin.registerWith(registry.registrarFor("plugins.flutter.io/shared_preferences"));


                    FlutterRunArguments args = new FlutterRunArguments();
                    args.bundlePath = FlutterMain.findAppBundlePath();
                    args.entrypoint = callbackInformation.callbackName;
                    args.libraryPath = callbackInformation.callbackLibraryPath;

                    backgroundView.runFromBundle(args);
                    backgroundChannel = new MethodChannel(backgroundView, "background_isolate");

                    backgroundChannel.setMethodCallHandler((call, result) -> {
                        if (call.method.equals("auth")) {
                            if (!isNetworkAvailable())
                                result.error("no_internet", "No internet, retry in 10 seconds", "");
                            if (app == null) {
                                app = FirebaseApp.initializeApp(getApplicationContext(), new FirebaseOptions.Builder()
                                        .setProjectId(call.argument("project_id"))
                                        .setStorageBucket(call.argument("storage_bucket"))
                                        .setApiKey(call.argument("api_key"))
                                        .setDatabaseUrl(call.argument("firebase_url"))
                                        .setGcmSenderId(call.argument("client_id"))
                                        .setApplicationId(call.argument("application_id"))
                                        .build());
                            }
                            if(app == null) {
                                result.error("could_not_initialize", "Failed to initialize, app == null", "");
                            }
                            FirebaseInstanceId.getInstance(app).getInstanceId()
                                    .addOnCompleteListener(new OnCompleteListener<InstanceIdResult>() {
                                        @Override
                                        public void onComplete(@NonNull Task<InstanceIdResult> task) {
                                            if (!task.isSuccessful()) {
                                                Log.d("FCM", "getInstanceId failed", task.getException());
                                                result.error("failed", "getInstanceId failed", task.getException());
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
                        } else if (call.method.equals("new-message-notification")) {
                            Log.d("background_isolate", "creating notification android side");
                            //occurs when clicking on the notification
                            PendingIntent openIntent = PendingIntent.getActivity(getApplicationContext(), call.argument("notificationId"), new Intent(getApplicationContext(), MainActivity.class).putExtra("id", (int) call.argument("notificationId")).putExtra("chatGUID", (String) call.argument("group")).setType("NotificationOpen"), Intent.FILL_IN_ACTION);

                            //for the dismiss button
                            PendingIntent dismissIntent = PendingIntent.getBroadcast(getApplicationContext(), call.argument("notificationId"), new Intent(getApplicationContext(), ReplyReceiver.class).putExtra("id", (int) call.argument("notificationId")).putExtra("chatGuid", (String) call.argument("group")).setType("markAsRead"), PendingIntent.FLAG_UPDATE_CURRENT);
                            NotificationCompat.Action dismissAction = new NotificationCompat.Action.Builder(0, "Mark As Read", dismissIntent).build();

//                            //for the quick reply
//                            Intent intent = new Intent(getApplicationContext(), ReplyReceiver.class)
//                                    .putExtra("id", (int) call.argument("notificationId"))
//                                    .putExtra("chatGuid", (String) call.argument("group"))
//                                    .setType("reply");
//                            PendingIntent replyIntent = PendingIntent.getBroadcast(getApplicationContext(), call.argument("notificationId"), intent, PendingIntent.FLAG_UPDATE_CURRENT);
//                            androidx.core.app.RemoteInput replyInput = new androidx.core.app.RemoteInput.Builder("key_text_reply").setLabel("Reply").build();
//                            NotificationCompat.Action replyAction = new NotificationCompat.Action.Builder(0, "Reply", replyIntent).addRemoteInput(replyInput).build();

                            //actual notification
                            NotificationCompat.Builder builder = new NotificationCompat.Builder(getApplicationContext(), call.argument("CHANNEL_ID"))
                                    .setSmallIcon(R.mipmap.ic_launcher)
                                    .setContentTitle(call.argument("contentTitle"))
                                    .setContentText(call.argument("contentText"))
                                    .setAutoCancel(true)
                                    .setContentIntent(openIntent)
                                    .addAction(dismissAction)
//                                    .addAction(replyAction)
                                    .setGroup(call.argument("group"));
//                                        .setGroup("messageGroup");
                            if (call.argument("address") != null) {
                                builder.addPerson(call.argument("address"));
                            }

                            NotificationCompat.Builder summaryBuilder = new NotificationCompat.Builder(getApplicationContext(), call.argument("CHANNEL_ID"))
                                    .setSmallIcon(R.mipmap.ic_launcher)
                                    .setContentTitle("New messages")
                                    .setGroup(call.argument("group"))
                                    .setAutoCancel(true)
                                    .setContentIntent(openIntent)
                                    .setGroupSummary(true);

                            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(getApplicationContext());

                            notificationManager.notify(call.argument("notificationId"), builder.build());
                            notificationManager.notify(call.argument("summaryId"), summaryBuilder.build());
                            result.success("");
                        }
                    });
                }
            });
        }
    }

    private ValueEventListener dbListener = new ValueEventListener() {
        @Override
        public void onDataChange(@NonNull DataSnapshot dataSnapshot) {
            Log.d("firebase", "data changed");
            String serverURL = dataSnapshot.child("config").child("serverUrl").getValue().toString();
            Log.d("firebase", "new server: " + serverURL);
            if (engine == null && backgroundChannel != null) {
                backgroundChannel.invokeMethod("new-server", "[" + serverURL + "]");
            }
        }

        @Override
        public void onCancelled(@NonNull DatabaseError databaseError) {

        }
    };

    private void destroyHeadlessThread() {
        if (backgroundView == null) return;
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                if (backgroundView != null) {
                    try {
                        backgroundView.destroy();
                    } catch (Exception e) {

                    }
                }
            }
        });
    }

    public LocalBroadcastManager broadcaster;

    public class LocalBinder extends Binder {
        BackgroundService getService() {
            return BackgroundService.this;
        }
    }

    @Override
    public void onDestroy() {
        backgroundServiceActive = false;
        Log.d("killing", "backgroundService killed");
        super.onDestroy();
    }


    @Override
    public void onCreate() {
//       startForegroundService()
        Log.d("isolate", "created background service");

        backgroundServiceActive = true;

        broadcaster = LocalBroadcastManager.getInstance(this);
    }



    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i("LocalService", "Received start id " + startId + ": " + intent);
        if (intent != null && intent.getExtras() != null && intent.getExtras().getBoolean("fromBackground")) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                CharSequence name = "startup";
                String description = "for testing";
                int importance = NotificationManager.IMPORTANCE_HIGH;
                NotificationChannel channel = new NotificationChannel("someChannel", name, importance);
                channel.setDescription(description);
                // Register the channel with the system; you can't change the importance
                // or other notification behaviors after this
                NotificationManager notificationManager = getSystemService(NotificationManager.class);
                notificationManager.createNotificationChannel(channel);
            }
            NotificationCompat.Builder builder = new NotificationCompat.Builder(getApplicationContext(), "someChannel")
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle("BlueBubbles Service")
                    .setContentText("BlueBubbles is running in the background");


            startForeground(new Random().nextInt(), builder.build());
            initHeadlessThread();

        } else {
            destroyHeadlessThread();
        }
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return mBinder;
    }


    private final IBinder mBinder = new LocalBinder();

    private boolean isNetworkAvailable() {
        ConnectivityManager connectivityManager
                = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
        return activeNetworkInfo != null && activeNetworkInfo.isConnected();
    }
}
