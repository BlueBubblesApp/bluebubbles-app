package com.bluebubbles.messaging.services.system

import android.content.Context
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// The preferences plugin writes with apply(), so a process exit can beat its writes to disk. A commit() waits for them.
class FlushPreferencesHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "flush-preferences"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit().commit()
        result.success(null)
    }
}
