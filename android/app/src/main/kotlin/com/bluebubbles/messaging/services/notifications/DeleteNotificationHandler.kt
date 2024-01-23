package com.bluebubbles.messaging.services.notifications

import android.app.NotificationManager
import android.content.Context
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DeleteNotificationHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "delete-notification"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val notificationId: Int = call.argument("notification_id")!!
        val success = deleteNotification(context, notificationId)
        if (success) {
            result.success(null)
        } else {
            result.error("500", "Failed to cancel notification!", null)
        }
    }

    fun deleteNotification(context: Context, notificationId: Int): Boolean {
        Log.d(Constants.logTag, "Cancelling notification with ID $notificationId")
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        return try {
            // We don't know what type of notification is being cancelled so explicitly do both
            notificationManager.cancel(Constants.newMessageNotificationTag, notificationId)
            notificationManager.cancel(Constants.newFaceTimeNotificationTag, notificationId)
            // cancel the summary if needed
            if (notificationManager.activeNotifications.size == 1 && notificationManager.activeNotifications.first().id == 0) {
                Log.d(Constants.logTag, "Cancelling notification summary")
                notificationManager.cancel(Constants.newMessageNotificationTag, 0)
            }
            true
        } catch (exception: Exception) {
            Log.e(Constants.logTag, "Failed to cancel notification with ID $notificationId!")
            false
        }
    }
}