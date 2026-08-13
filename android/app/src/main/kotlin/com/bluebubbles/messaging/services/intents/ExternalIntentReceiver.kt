package com.bluebubbles.messaging.services.intents

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.utils.PersistentLog
import com.bluebubbles.messaging.utils.Utils
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

/// Receives intents from other apps. This is primarily used for Tasker integration.
///
/// SECURITY: this receiver is exported with no permission, so any app installed on
/// the device can send it intents. Treat every extra as hostile input.
class ExternalIntentReceiver: BroadcastReceiver() {

    companion object {
        private const val TASKER_PACKAGE = "net.dinglisch.android.taskerm"

        /// Constant-time string compare. `==` short-circuits at the first differing
        /// byte, which any app can time to guess the password one byte at a time.
        /// Length still leaks (isEqual returns early on it); contents don't.
        internal fun constantTimeEquals(a: String, b: String): Boolean =
            MessageDigest.isEqual(a.toByteArray(Charsets.UTF_8), b.toByteArray(Charsets.UTF_8))
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        PersistentLog.d(context, Constants.logTag, "Received intent ${intent.action} from external app")
        when (intent.action) {
            "com.bluebubbles.external.GET_SERVER_URL" -> {
                val password = intent.extras?.getString("password")
                val identifier = intent.extras?.getString("id")
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", 0)
                val storedPassword = prefs.getString("guidAuthKey", "")

                // guidAuthKey defaults to "" before setup, so an empty password must
                // never authenticate.
                if (password.isNullOrEmpty() || storedPassword.isNullOrEmpty()) {
                    PersistentLog.d(context, Constants.logTag, "Rejected GET_SERVER_URL: missing password")
                    return
                }
                if (!constantTimeEquals(password, storedPassword)) {
                    PersistentLog.d(context, Constants.logTag, "Rejected GET_SERVER_URL: bad password")
                    return
                }

                Utils.getServerUrl(context, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        PersistentLog.d(context, Constants.logTag, "Got server URL - sending to Tasker...")
                        val reply = Intent()
                        reply.setAction("net.dinglisch.android.taskerm.BB_SERVER_URL")
                        reply.putExtra("url", result.toString())
                        reply.putExtra("id", identifier)
                        // Must stay package-targeted: an untargeted broadcast exposes
                        // the server URL to any app listening for this action.
                        reply.setPackage(TASKER_PACKAGE)
                        context.sendBroadcast(reply)
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                    override fun notImplemented() {}
                })
            }
        }
    }
}
