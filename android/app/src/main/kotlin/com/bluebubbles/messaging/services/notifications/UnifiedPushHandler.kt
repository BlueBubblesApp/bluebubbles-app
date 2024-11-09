package com.bluebubbles.messaging.services.notifications

import android.content.Context
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.unifiedpush.android.connector.UnifiedPush

class UnifiedPushHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "UnifiedPushHandler"
    }
    public fun registerUnifiedPush(context: Context) {
        UnifiedPush.registerAppWithDialog(context)
    }

    public fun unregisterUnifiedPush(context: Context) {
        UnifiedPush.unregisterApp(context)
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val operation: String? = call.argument("operation")
        when(operation) {
            "register" -> this.registerUnifiedPush(context)
            "unregister" -> this.unregisterUnifiedPush(context)
            else -> {
                result.error("500", "invalid operation argument '$operation'", null)
                return
            }
        }
        result.success(null)
    }

}

