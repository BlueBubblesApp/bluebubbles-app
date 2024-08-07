package com.bluebubbles.messaging.services.foreground

import android.os.Build
import android.content.Context
import android.content.Intent
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.bluebubbles.messaging.services.foreground.SocketIOForegroundService

/// Start the foreground service
class StartForegroundServiceHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "start-foreground-service"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        try {
            val serviceIntent = Intent(context, SocketIOForegroundService::class.java)
            if (context != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent);
                } else {
                    context.startService(serviceIntent);
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("START_FOREGROUND_SERVICE_ERROR", e.message, e)
        }
    }
}