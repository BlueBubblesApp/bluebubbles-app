package com.bluebubbles.messaging.services.firebase

import android.content.Context
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.utils.PersistentLog
import com.google.android.gms.tasks.Task
import com.google.firebase.FirebaseApp
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.firestore.FirebaseFirestore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

/// Fetches a new URL immediately from Firebase
class ServerUrlRequestHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "get-server-url"
        const val offlineCode: String = "OFFLINE"
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
        PersistentLog.d(context, Constants.logTag, "Fetching server URL...")
        if (firebaseApp.options.databaseUrl == null) {
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    val serverUrlTask: Task<DocumentSnapshot> = withContext(Dispatchers.IO) {
                        FirebaseFirestore.getInstance().collection("server").document("config").get()
                    }
                    val serverUrl: String? = serverUrlTask.await().data?.get("serverUrl") as String?
                    submitData(serverUrl, result)
                } catch (e: FirebaseFirestoreException) {
                    if (e.code == FirebaseFirestoreException.Code.UNAVAILABLE) {
                        PersistentLog.w(
                            context,
                            Constants.logTag,
                            "Firestore is offline/unavailable while fetching server URL. Keeping existing URL.",
                            e,
                        )
                        result.error(offlineCode, "Firestore unavailable/offline", null)
                        return@launch
                    }
                    PersistentLog.e(
                        context,
                        Constants.logTag,
                        "Failed to fetch Firestore server URL (${e.code}): ${e.message}",
                        e,
                    )
                    result.error("403", "Missing or insufficient Firebase permissions", null)
                } catch (e: Exception) {
                    val rootCause = e.cause
                    if (rootCause is FirebaseFirestoreException && rootCause.code == FirebaseFirestoreException.Code.UNAVAILABLE) {
                        PersistentLog.w(
                            context,
                            Constants.logTag,
                            "Firestore is offline/unavailable while fetching server URL. Keeping existing URL.",
                            e,
                        )
                        result.error(offlineCode, "Firestore unavailable/offline", null)
                        return@launch
                    }
                    PersistentLog.e(context, Constants.logTag, "Failed to fetch Firestore server URL", e)
                    result.error("500", "Failed to get server URL from Firestore", null)
                }
            }
        } else {
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    val serverUrlTask: Task<DataSnapshot> = withContext(Dispatchers.IO) {
                        FirebaseDatabase.getInstance().getReference("config").child("serverUrl").get()
                    }
                    val serverUrl: String? = serverUrlTask.await().getValue(String::class.java)
                    submitData(serverUrl, result)
                } catch (e: Exception) {
                    PersistentLog.e(context, Constants.logTag, "Failed to fetch Realtime DB server URL", e)
                    result.error("500", "Failed to get server URL from Realtime Database", null)
                }
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
