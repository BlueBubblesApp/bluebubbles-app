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
import com.google.firebase.firestore.DocumentReference;
import com.google.firebase.firestore.FirebaseFirestore;

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
            Log.d(TAG, "client_id: " + call.argument("client_id"));
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
                            Log.d(TAG, "getInstanceId failed", task.getException());
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

        if (call.argument("firebase_url") == null) {
            try {
                FirebaseFirestore db = FirebaseFirestore.getInstance();
                DocumentReference doc = db.collection("server").document("config");
                // Add the listener
                doc.addSnapshotListener(DBListener.cfdbListener);
            } catch (Exception e) {}
        } else {
            try {
                db = FirebaseDatabase.getInstance(app).getReference("config");
                // Remove any previous listeners and re-add the listener
                db.removeEventListener(DBListener.rtdbListener);
                db.addValueEventListener(DBListener.rtdbListener);
            } catch (Exception e) {}
        }
    }


    private static boolean isNetworkAvailable(Context context) {
        ConnectivityManager connectivityManager
                = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
        return activeNetworkInfo != null && activeNetworkInfo.isConnected();
    }
}
