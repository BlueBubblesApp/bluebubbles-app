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
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
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
import androidx.annotation.RequiresApi;
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
import com.itsclicking.clickapp.fluttersocketio.SocketIOManager;
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
    public FlutterNativeView backgroundView;
    public MethodChannel backgroundChannel;
    public static FirebaseApp app;

    public static DatabaseReference db;

    private Map<Integer, NotificationCompat.Builder> progressBars = new HashMap<>();

    public boolean isAlive() {
        return isAlive;
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    public void setAlive(boolean val) {
        isAlive = val;
        if (!val) {
            SocketIOManager.getInstance().destroyAllSockets();
            initHeadlessThread();
        } else {
            Log.d("headless", "destroying headless thread");
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
        if (backgroundView != null && backgroundChannel != null) {
            backgroundChannel.invokeMethod("requestFCMAuth", "");
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    private void initHeadlessThread() {
        if (backgroundView == null) {
            FlutterMain.ensureInitializationComplete(getApplicationContext(), null);

            Long callbackHandle = getApplicationContext().getSharedPreferences(MainActivity.BACKGROUND_SERVICE_SHARED_PREF, Context.MODE_PRIVATE).getLong(MainActivity.BACKGROUND_HANDLE_SHARED_PREF_KEY, 0);
            FlutterCallbackInformation callbackInformation = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle);

//            new Handler(Looper.getMainLooper()).post(new Runnable() {
//                @Override
//                public void run() {
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

            backgroundChannel.setMethodCallHandler((call, result) -> MainActivity.methodCallHandler(call, result, getApplicationContext(), dbListener, null)
            );
        }
    }

    private ValueEventListener dbListener = new ValueEventListener() {
        @Override
        public void onDataChange(@NonNull DataSnapshot dataSnapshot) {
            Log.d("firebase", "data changed");
            if (dataSnapshot.child("config").child("serverUrl").getValue() == null) return;
            String serverURL = dataSnapshot.child("config").child("serverUrl").getValue().toString();
            Log.d("FirebaseDB", "Current server URL: " + serverURL);
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
//        new Handler(Looper.getMainLooper()).post(new Runnable() {
//            @Override
//            public void run() {
        if (backgroundView != null) {
            try {
                backgroundView.destroy();
                backgroundView = null;
                backgroundChannel = null;
            } catch (Exception e) {

            }
        }
//            }
//        });
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


    @RequiresApi(api = Build.VERSION_CODES.M)
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i("LocalService", "Received start id " + startId + ": " + intent);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            CharSequence name = "Background Service";
            String description = "Persistent notification showing that bluebubbles is running in the background";
            int importance = NotificationManager.IMPORTANCE_LOW;
            NotificationChannel channel = new NotificationChannel("background_notification_channel", name, importance);
            channel.setDescription(description);
            channel.setShowBadge(false);
            // Register the channel with the system; you can't change the importance
            // or other notification behaviors after this
            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            notificationManager.createNotificationChannel(channel);
        }
        NotificationCompat.Builder builder = new NotificationCompat.Builder(getApplicationContext(), "background_notification_channel")
                .setSmallIcon(R.mipmap.ic_stat_icon)
                .setContentTitle("BlueBubbles Service")
                .setContentText("BlueBubbles is running in the background");


        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.ECLAIR) {
            startForeground(startId, builder.build());
        }
        if (intent != null && intent.getExtras() != null && intent.getExtras().getBoolean("fromBackground")) {
            initHeadlessThread();
            isAlive = false;

        } else {
            Log.d("headless", "destroying headless thread");
            destroyHeadlessThread();
            isAlive = true;
        }
        return START_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return mBinder;
    }


    private final IBinder mBinder = new LocalBinder();

}
