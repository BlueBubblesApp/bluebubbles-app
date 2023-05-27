package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;

import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static com.bluebubbles.messaging.method_call_handler.handlers.FirebaseAuth.app;

public class GetServerUrl implements Handler {

    public static String TAG = "get-server-url";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public GetServerUrl(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        // If we don't have an app yet, don't do anything
        if (app == null) {
            result.success(null);
            return;
        }

        // Get the server URL from Firebase
        FirebaseDatabase database = FirebaseDatabase.getInstance(app);
        if (app.getOptions().getDatabaseUrl() == null) {
            FirebaseFirestore db = FirebaseFirestore.getInstance();
            if (db != null) {
                db.collection("server").document("config").get().addOnCompleteListener(new OnCompleteListener<DocumentSnapshot>() {
                        @Override
                        public void onComplete(Task<DocumentSnapshot> task) {
                            if (task.isSuccessful()) {
                                DocumentSnapshot document = task.getResult();
                                result.success(document.getData().get("serverUrl"));
                            } else {
                                result.success(null);
                            }
                        }
                    });
            } else {
                result.success(null);
                return;
            }
        } else {
            database.getReference("config").child("serverUrl").get().addOnCompleteListener(new OnCompleteListener<DataSnapshot>() {
                @Override
                public void onComplete(Task<DataSnapshot> task) {
                    if (!task.isSuccessful()) {
                        result.success(null);
                    } else {
                        result.success(String.valueOf(task.getResult().getValue()));
                    }
                }
            });
        }
    }
}
