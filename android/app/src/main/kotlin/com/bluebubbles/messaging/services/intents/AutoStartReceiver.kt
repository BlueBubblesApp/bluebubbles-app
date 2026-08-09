package com.bluebubbles.messaging.services.intents

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.services.foreground.SocketIOForegroundService
import com.bluebubbles.messaging.utils.PersistentLog

/// Receives intents from the system. This is primarily used for auto starting after a reboot
class AutoStartReceiver: BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        PersistentLog.d(context, Constants.logTag, "Received intent ${intent.action} from auto start")
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                // Check to see if the foreground service is enabled
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", 0)
                val keepAppAlive: Boolean = prefs.getBoolean("keepAppAlive", false)

                // If the service is enabled, start it
                if (keepAppAlive) {
                    val serviceIntent = Intent(context, SocketIOForegroundService::class.java)
                    context.startForegroundService(serviceIntent)
                }
            }
        }
    }
}