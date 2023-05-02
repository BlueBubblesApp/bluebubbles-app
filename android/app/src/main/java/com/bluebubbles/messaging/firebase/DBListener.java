package com.bluebubbles.messaging.firebase;

import android.util.Log;
import java.util.Map;

import androidx.annotation.NonNull;

import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.ValueEventListener;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.EventListener;
import com.google.firebase.firestore.FirebaseFirestoreException;

import io.flutter.plugin.common.MethodChannel;

import static com.bluebubbles.messaging.MainActivity.CHANNEL;
import static com.bluebubbles.messaging.MainActivity.engine;

public class DBListener {
    public static ValueEventListener rtdbListener = new ValueEventListener() {
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

    public static EventListener<DocumentSnapshot> cfdbListener = new EventListener<DocumentSnapshot>() {
        @Override
        public void onEvent(DocumentSnapshot documentSnapshot, FirebaseFirestoreException error) {
            if (documentSnapshot != null) {
                Log.d("FirebaseDB", "Realtime database updated. Syncing...");
                Map data = documentSnapshot.getData();
                if (data != null) {
                    String serverURL = data.get("serverUrl").toString();
                    Log.d("FirebaseDB", "Current server URL: " + serverURL);
                    if (engine != null) {
                        new MethodChannel(engine.getDartExecutor().getBinaryMessenger(), CHANNEL).invokeMethod("new-server", "[" + serverURL + "]");
                    }
                }
            }
        }
    };
}
