package com.bluebubbles.messaging.services.firebase

import android.util.Log
import com.bluebubbles.messaging.Constants
import com.google.android.gms.tasks.Task
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

class FirebaseCloudMessagingTokenHandler {
    fun getToken(result: MethodChannel.Result?) {
        Log.d(Constants.logTag, "Fetching FCM token...")
        // Attempt to get an FCM registration token to pass to the server
        val tokenTask: Task<String> = FirebaseMessaging.getInstance().token;
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val fcmToken: String = tokenTask.await()
                result?.success(fcmToken)
            } catch (exception: Exception) {
                val error = "Failed to get FCM token!"
                Log.e(Constants.logTag, error)
                result?.error("500", error, exception)
            }
        }
    }

    fun deleteToken(result: MethodChannel.Result?) {
        Log.d(Constants.logTag, "Deleting FCM token...")
        // Attempt to delete FCM registration token
        CoroutineScope(Dispatchers.Main).launch {
            try {
                FirebaseMessaging.getInstance().deleteToken().await()
                result?.success(null)
            } catch (exception: Exception) {
                val error = "Failed to delete FCM token!"
                Log.e(Constants.logTag, error)
                result?.error("500", error, exception)
            }
        }
    }
}