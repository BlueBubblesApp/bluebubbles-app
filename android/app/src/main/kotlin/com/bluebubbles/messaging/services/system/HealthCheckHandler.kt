package com.bluebubbles.messaging.services.system

import android.content.Context
import android.util.Log
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.services.healthservice.HealthWorker
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class HealthCheckHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "health-check-setup"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        Log.i(tag, "Handling health check method")

        if (call.argument("enabled") as? Boolean == true) {
            HealthWorker.registerHealthChecking(context)
        } else if (call.argument("enabled") as? Boolean == false) {
            HealthWorker.cancelHealthChecking(context)
        }

        result.success(null)
    }
}