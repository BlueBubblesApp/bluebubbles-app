package com.bluebubbles.messaging.firebase;

import android.util.Log;

import androidx.annotation.NonNull;

import com.bluebubbles.messaging.workers.FCMWorker;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.ValueEventListener;

import io.flutter.plugin.common.MethodChannel;

import static com.bluebubbles.messaging.MainActivity.CHANNEL;
import static com.bluebubbles.messaging.MainActivity.engine;

public class DBListener {
    public static ValueEventListener dbListener = new ValueEventListener() {
        @Override
        public void onDataChange(@NonNull DataSnapshot dataSnapshot) {
            Log.d("FirebaseDB", "Firebase Database updated. Syncing...");
            String serverURL = dataSnapshot.child("serverUrl").getValue().toString();
            Log.d("FirebaseDB", "Current server URL: " + serverURL);
            if (engine != null) {
                new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("new-server", "[" + serverURL + "]");
            }
        }

        @Override
        public void onCancelled(@NonNull DatabaseError databaseError) {

        }
    };
}
