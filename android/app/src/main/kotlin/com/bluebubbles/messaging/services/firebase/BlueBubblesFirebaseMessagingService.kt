package com.bluebubbles.messaging.services.firebase

import android.content.Intent
import android.util.Log
import androidx.core.os.bundleOf
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.services.backend_ui_interop.DartWorkManager
import com.bluebubbles.messaging.utils.Utils
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugin.common.MethodChannel

class BlueBubblesFirebaseMessagingService: FirebaseMessagingService() {
    override fun onCreate() {
        super.onCreate()
        Log.d(Constants.logTag, "FCM service created")
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        val type = message.data["type"] ?: return
        Log.d(Constants.logTag, "Received new message of type $type from FCM...")
        DartWorkManager.createWorker(applicationContext, type, HashMap(message.data)) {}

        // check if the user configured "Send Events to Tasker"
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", 0)
        if (prefs.getBoolean("flutter.sendEventsToTasker", false)) {
            Utils.getServerUrl(applicationContext, prefs.getString("flutter.guidAuthKey", "")!!, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.d(Constants.logTag, "Got URL: $result - sending to Tasker...")
                    val intent = Intent()
                    intent.setAction("net.dinglisch.android.taskerm.BB_SERVER_URL")
                    intent.putExtra("url", result.toString())
                    intent.putExtra("event", type)
                    intent.putExtras(bundleOf(*message.data.toList().toTypedArray()))
                    applicationContext.sendBroadcast(intent)
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            })
        }
    }
}