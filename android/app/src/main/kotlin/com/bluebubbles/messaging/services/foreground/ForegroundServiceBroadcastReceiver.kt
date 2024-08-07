package com.bluebubbles.messaging.services.foreground

import android.os.Build
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.services.foreground.SocketIOForegroundService

class ForegroundServiceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(Constants.logTag, "Received Foreground Service Broadcast");

        if (context != null) {
            Log.d(Constants.logTag, "Showing Foreground Service Broadcast Toast");
            Toast.makeText(context, "BlueBubbles Service Restarted...", Toast.LENGTH_SHORT).show();

            val intent = Intent(context, SocketIOForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent);
            } else {
                context.startService(intent);
            }
        }
    }
}