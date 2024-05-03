package com.bluebubbles.messaging.services.intents

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.utils.Utils
import io.flutter.plugin.common.MethodChannel

/// Receives intents from other apps. This is primarily used for Tasker integration.
class ExternalIntentReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        Log.d(Constants.logTag, "Received intent ${intent.action} from external app")
        when (intent.action) {
            "com.bluebubbles.external.GET_SERVER_URL" -> {
                val password = intent.extras?.getString("password")
                val identifier = intent.extras?.getString("id")
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", 0)
                val storedPassword = prefs.getString("flutter.guidAuthKey", "")

                if (password == storedPassword) {
                    Utils.getServerUrl(context, object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            Log.d(Constants.logTag, "Got URL: $result - sending to Tasker...")
                            val intent = Intent()
                            intent.setAction("net.dinglisch.android.taskerm.BB_SERVER_URL")
                            intent.putExtra("url", result.toString())
                            intent.putExtra("id", identifier)
                            context.sendBroadcast(intent)
                        }

                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                        override fun notImplemented() {}
                    })
                }
            }
        }
    }
}