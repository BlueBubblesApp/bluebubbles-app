package com.bluebubbles.messaging.services.notifications

import android.content.Context
import android.content.Intent
import android.provider.Settings
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.MainActivity
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.services.backend_ui_interop.MethodCallHandler
import com.bluebubbles.messaging.utils.PersistentLog
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Used to request the notification listener permission
class NotificationListenerPermissionRequestHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "request-notification-listener-permission"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val hasPermission = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners").contains(context.packageName)
        if (hasPermission) {
            PersistentLog.d(context, Constants.logTag, "Notification listener permission already granted, ignoring...")
            return result.success(true)
        }
        val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
        try {
            MethodCallHandler.setNotificationListenerResult(result)
            (context as MainActivity).startActivityForResult(intent, Constants.notificationListenerRequestCode)
        } catch (e: Exception) {
            MethodCallHandler.clearNotificationListenerResult()
            result.error("500", "Failed to launch notification listener settings", e.localizedMessage)
        }
    }
}