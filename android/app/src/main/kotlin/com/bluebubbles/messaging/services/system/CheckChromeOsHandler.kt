package com.bluebubbles.messaging.services.system

import android.content.Context
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Check if ChromeOS is the current OS
class CheckChromeOsHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "check-chromeos"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val packageManager = context.packageManager;
        result.success(packageManager.hasSystemFeature("org.chromium.arc") || packageManager.hasSystemFeature("org.chromium.arc.device_management"))
    }
}