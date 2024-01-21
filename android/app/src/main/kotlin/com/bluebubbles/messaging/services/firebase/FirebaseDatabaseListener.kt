package com.bluebubbles.messaging.services.firebase

import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.services.backend_ui_interop.MethodCallHandler
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.ValueEventListener
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.EventListener
import com.google.firebase.firestore.FirebaseFirestoreException

class RealtimeDatabaseListener: ValueEventListener {
    override fun onDataChange(snapshot: DataSnapshot) {
        Log.d(Constants.logTag, "Realtime Database updated with new URL. Fetching...")
        val serverUrl: String? = snapshot.child("serverUrl").getValue(String::class.java)
        if (serverUrl != null) {
            MethodCallHandler.invokeMethod("NewServerUrl", mapOf("server_url" to serverUrl))
        } else {
            Log.e(Constants.logTag, "Realtime Database provided invalid URL!")
        }
    }

    override fun onCancelled(error: DatabaseError) {
        Log.e(Constants.logTag, "Realtime Database failed to provide a new URL!")
    }
}

class FirestoreDatabaseListener: EventListener<DocumentSnapshot> {
    override fun onEvent(value: DocumentSnapshot?, error: FirebaseFirestoreException?) {
        if (value != null) {
            Log.d(Constants.logTag, "Firestore Database updated with new URL. Fetching...")
            val serverUrl: String? = value.get("serverUrl", String::class.java)
            if (serverUrl != null) {
                MethodCallHandler.invokeMethod("NewServerUrl", mapOf("server_url" to serverUrl))
            } else {
                Log.e(Constants.logTag, "Firestore Database provided invalid URL!")
            }
        } else {
            Log.e(Constants.logTag, "Firestore Database failed to provide a new URL!")
        }
    }
}