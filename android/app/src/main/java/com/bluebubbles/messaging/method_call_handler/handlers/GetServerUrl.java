package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;

import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static com.bluebubbles.messaging.method_call_handler.handlers.FirebaseAuth.app;

public class GetServerUrl implements Handler{

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
        // Get the server URL from Firebase
        DatabaseReference database = FirebaseDatabase.getInstance(app).getReference("config");
        ValueEventListener listener = new ValueEventListener() {
            @Override
            public void onDataChange(DataSnapshot dataSnapshot) {
                String url = (String) dataSnapshot.child("serverUrl").getValue();
                result.success(url);
            }

            @Override
            public void onCancelled(DatabaseError databaseError) {
                result.success(null);
            }
        };

        database.addListenerForSingleValueEvent(listener);
    }
}
