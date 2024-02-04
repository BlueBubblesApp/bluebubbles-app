package com.bluebubbles.messaging.services.notifications

import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.R
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ConnectionErrorNotification: MethodCallHandlerImpl() {
    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        if (call.argument("operation") as? String == "create") {
            createErrorNotification(context)
        } else if (call.argument("operation") as? String == "clear") {
            clearErrorNotification(context)
        }

        result.success(null)
    }

    fun createErrorNotification(context: Context) {
        val notificationBuilder = NotificationCompat.Builder(context, "com.bluebubbles.errors")
            .setSmallIcon(R.mipmap.ic_stat_icon)
            .setAutoCancel(false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_ERROR)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setContentTitle("Could not connect")
            .setContentText("Your server may be offline!")
            .setColor(0x4990de)

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(Constants.newFaceTimeNotificationTag, NOTIFICATION_ID, notificationBuilder.build())
    }

    fun clearErrorNotification(context: Context) {
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.cancel(NOTIFICATION_ID)
    }

    companion object {
        const val tag = "connection-error-notification"

        private const val NOTIFICATION_ID = -2
    }

}