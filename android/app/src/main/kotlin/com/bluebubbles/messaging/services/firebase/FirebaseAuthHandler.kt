package com.bluebubbles.messaging.services.firebase

import android.content.Context
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.utils.PersistentLog
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.firestore.FirebaseFirestore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

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
        try {
            FirebaseApp.getInstance()
            PersistentLog.d(context, Constants.logTag, "Firebase has already been initialized!")
            result.success(null)
            return
        } catch (_: IllegalStateException) {}
        // Make sure Google Services are available
        if (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context) != ConnectionResult.SUCCESS) {
            val error = "Google Play Services is not available!"
            PersistentLog.e(context, Constants.logTag, error)
            result.error("500", error, null)
            return
        }

        // Fetch Firebase details directly from preferences
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", 0)
        val projectId: String? = prefs.getString("projectID", null)
        val storageBucket: String? = prefs.getString("storageBucket", null)
        val apiKey: String = prefs.getString("apiKey", null)!!
        val databaseUrl: String? = prefs.getString("firebaseURL", null)
        val gcmSenderId: String? = prefs.getString("clientID", null)
        val applicationId: String = prefs.getString("applicationID", null)!!

        PersistentLog.d(context, Constants.logTag, "Authenticating client $applicationId with Firebase...")
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

        // Set up Firestore / Realtime DB listeners for server URL changes
        // databaseUrl null indicates Cloud Firestore setup
        PersistentLog.d(context, Constants.logTag, "Setting Firebase database listeners...")
        if (databaseUrl == null) {
            FirebaseFirestore.getInstance().collection("server").document("config").addSnapshotListener(FirestoreDatabaseListener())
        } else {
            FirebaseDatabase.getInstance().getReference("config").addValueEventListener(RealtimeDatabaseListener())
        }

        FirebaseCloudMessagingTokenHandler().getToken(context, result)
    }
}