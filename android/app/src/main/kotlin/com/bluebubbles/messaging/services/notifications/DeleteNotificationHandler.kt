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
        Log.d(Constants.logTag, "Attempting to delete notification with ID, $notificationId")
        val notificationManager = context.getSystemService(NotificationManager::class.java)

        try {
            // Get the notification by ID
            val notification = notificationManager.activeNotifications.firstOrNull { it.id == notificationId }

            // If it's null, we can't cancel it.
            // Return true cuz there wasn't technically an issue.
            if (notification == null) {
                Log.d(Constants.logTag, "Notification with ID $notificationId not found!")
            } else {
                Log.d(Constants.logTag, "Cancelling notification with tag ${notification.tag}")
                notificationManager.cancel(notification.tag, notificationId)
            }

            // Get all notifications of the same tag/channel
            val leftoverNotifications = notificationManager.activeNotifications.filter { it.tag == notification.tag }

            // If the number of notifications is 1 and the ID of the notification is 0, it's a summary notification.
            // We should cancel it.
            if (leftoverNotifications.size == 1 && leftoverNotifications.first().id == 0) {
                Log.d(Constants.logTag, "Cancelling notification summary")
                notificationManager.cancel(notification.tag, 0)
            }

            return true
        } catch (exception: Exception) {
            Log.e(Constants.logTag, "Failed to cancel notification with ID $notificationId!")
            return false
        }
        
        return true
    }
}