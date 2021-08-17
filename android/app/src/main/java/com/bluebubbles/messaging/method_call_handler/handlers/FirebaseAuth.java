package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.util.Log;

import androidx.annotation.NonNull;

import com.bluebubbles.messaging.firebase.DBListener;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;

import java.lang.reflect.Method;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;


public class FirebaseAuth implements Handler {
    public static String TAG = "auth";
    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;
    public static FirebaseApp app;
    public static DatabaseReference db;

    public FirebaseAuth(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        if (!isNetworkAvailable(context))
            result.error("no_internet", "No internet, retry in 10 seconds", "");
        if (app == null) {
            Log.d("firebase_auth", "client_id: " + call.argument("client_id"));
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
        FirebaseMessaging.getInstance().getToken()
                .addOnCompleteListener(new OnCompleteListener<String>() {
                    @Override
                    public void onComplete(@NonNull Task<String> task) {
                        if (task.getResult() == null || !task.isSuccessful()) {
                            Log.d("FCM", "getInstanceId failed", task.getException());
                            try {

                                result.error("Failed to authenticate", "getInstanceId failed", task.getException());
                            } catch (IllegalStateException e) {

                            }
                            return;
                        }

                        String token = task.getResult();
                        Log.d("FCM", "token: " + token);
                        try {
                            result.success(token);
                        } catch (IllegalStateException e) {
                        }
                    }
                });

        // Get the config database reference
        db = FirebaseDatabase.getInstance(app).getReference("config");
        try {
            // Remove any previous listeners
            db.removeEventListener(DBListener.dbListener);
        } catch (Exception e) {
            // Don't do anything
        }

        // Re-add the listener
        db.addValueEventListener(DBListener.dbListener);
    }


    private static boolean isNetworkAvailable(Context context) {
        ConnectivityManager connectivityManager
                = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
        return activeNetworkInfo != null && activeNetworkInfo.isConnected();
    }
}
