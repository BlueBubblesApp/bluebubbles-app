package com.bluebubbles.messaging.services.firebase

import android.content.Context
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.google.android.gms.tasks.Task
import com.google.firebase.FirebaseApp
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FirebaseFirestore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/// Fetches a new URL immediately from Firebase
class ServerUrlRequestHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "get-server-url"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        // Make sure a FirebaseApp is initialized
        lateinit var firebaseApp: FirebaseApp
        try {
            firebaseApp = FirebaseApp.getInstance()
        } catch (e: Exception) {
            result.error("500", "No Firebase app found!", e)
            return
        }

        // Get server URL via Firestore or Realtime DB
        Log.d(Constants.logTag, "Fetching server URL...")
        if (firebaseApp.options.databaseUrl == null) {
            CoroutineScope(Dispatchers.Main).launch {
                val serverUrlTask: Task<DocumentSnapshot> = FirebaseFirestore.getInstance().collection("server").document("config").get()
                val serverUrl: String? = serverUrlTask.await().get("serverUrl", String::class.java)
                submitData(serverUrl, result)
            }
        } else {
            CoroutineScope(Dispatchers.Main).launch {
                val serverUrlTask: Task<DataSnapshot> = FirebaseDatabase.getInstance().getReference("config").child("serverUrl").get()
                val serverUrl: String? = serverUrlTask.await().getValue(String::class.java)
                submitData(serverUrl, result)
            }
        }
    }

    private fun submitData(serverUrl: String?, result: MethodChannel.Result) {
        if (serverUrl != null) {
            result.success(serverUrl)
        } else {
            result.error("500", "Failed to get server URL!", null)
        }
    }
}