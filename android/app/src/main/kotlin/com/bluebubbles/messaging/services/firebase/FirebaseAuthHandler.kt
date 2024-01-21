package com.bluebubbles.messaging.services.firebase

import android.content.Context
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.google.android.gms.tasks.Task
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

class FirebaseAuthHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "firebase-auth"
        var firebaseApp: FirebaseApp? = null
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        // Don't auth multiple times
        if (firebaseApp != null) result.success(null)

        val projectId: String? = call.argument("project_id")
        val storageBucket: String? = call.argument("storage_bucket")
        val apiKey: String = call.argument("api_key")!!
        val databaseUrl: String? = call.argument("firebase_url")
        val gcmSenderId: String? = call.argument("client_id")
        val applicationId: String = call.argument("application_id")!!

        Log.d(Constants.logTag, "Authenticating client $applicationId with Firebase...")
        // Get a FirebaseApp (manually provide config since we fetch it dynamically)
        firebaseApp = FirebaseApp.initializeApp(context, FirebaseOptions.Builder()
            .setApiKey(apiKey)
            .setApplicationId(applicationId)
            .setDatabaseUrl(databaseUrl)
            .setGcmSenderId(gcmSenderId)
            .setProjectId(projectId)
            .setStorageBucket(storageBucket)
            .build()
        )

        Log.d(Constants.logTag, "Fetching FCM token...")
        // Attempt to get an FCM registration token to pass to the server
        val tokenTask: Task<String> = FirebaseMessaging.getInstance().token;
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val fcmToken: String = tokenTask.await()
                result.success(fcmToken)
            } catch (exception: Exception) {
                val error = "Failed to get FCM token!"
                Log.e(Constants.logTag, error)
                result.error("500", error, exception)
            }

            // Set up Firestore / Realtime DB listeners for server URL changes
            // databaseUrl null indicates Cloud Firestore setup
            Log.d(Constants.logTag, "Setting Firebase database listeners...")
            if (databaseUrl == null) {
                FirebaseFirestore.getInstance().collection("server").document("config").addSnapshotListener(FirestoreDatabaseListener())
            } else {
                FirebaseDatabase.getInstance().getReference("config").addValueEventListener(RealtimeDatabaseListener())
            }
        }
    }
}