package com.bluebubbles.messaging.services.notifications

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.utils.PersistentLog
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
        val tag: String? = call.argument("tag")
        val readBefore: Long? = call.argument<Number>("read_before")?.toLong()
        if (readBefore != null && trimReadMessages(context, notificationId, readBefore)) {
            return result.success(null)
        }
        val success = deleteNotification(context, notificationId, tag, keepBubble = true)
        if (success) {
            result.success(null)
        } else {
            result.error("500", "Failed to cancel notification!", null)
        }
    }

    // Drops messages dated at or before [readBefore] from the chat notification and reposts it silently.
    // Returns false when nothing newer is left, so the caller deletes the whole notification.
    private fun trimReadMessages(context: Context, notificationId: Int, readBefore: Long): Boolean {
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        val active = notificationManager.activeNotifications.firstOrNull { it.id == notificationId } ?: return false
        val style = NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(active.notification)
            ?: return false
        PersistentLog.d(context, Constants.logTag, "Trimming notification $notificationId through $readBefore: ${style.messages.map { it.timestamp }}")
        if (style.messages.none { it.timestamp > readBefore }) return false
        if (style.messages.none { it.timestamp <= readBefore }) return true

        style.messages.removeAll { it.timestamp <= readBefore }
        val notification = NotificationCompat.Builder(context, active.notification)
            .setStyle(style)
            .setSilent(true)
            .build()
        notificationManager.notify(active.tag, notificationId, notification)
        return true
    }

    fun deleteNotification(context: Context, notificationId: Int, tag: String?, keepBubble: Boolean = false): Boolean {
        PersistentLog.d(context, Constants.logTag, "Attempting to delete notification with ID, $notificationId from tag, $tag")
        val notificationManager = context.getSystemService(NotificationManager::class.java)

        try {
            // Get the notification by ID
            val notification = notificationManager.activeNotifications.firstOrNull { it.id == notificationId }

            // If it's null, we can't cancel it.
            // Return true cuz there wasn't technically an issue.
            if (notification == null) {
                PersistentLog.d(context, Constants.logTag, "Notification with ID $notificationId not found!")
            } else if (keepBubble && hideBubbledNotification(context, notificationManager, notification)) {
                PersistentLog.d(context, Constants.logTag, "Hid bubbled notification with ID $notificationId instead of cancelling it")
                return true
            } else {
                PersistentLog.d(context, Constants.logTag, "Cancelling notification with ID, ${notificationId}")
                notificationManager.cancel(notification.tag, notificationId)
            }

            val channelTag: String? = notification?.tag ?: tag
            PersistentLog.d(context, Constants.logTag, "Using Channel Tag: $channelTag (Notif: ${notification?.tag}; Param: $tag)")
            if (channelTag != null) {
                // Get all notifications of the same tag/channel, excluding the one we just cancelled
                val leftoverNotifications = notificationManager.activeNotifications.filter {
                    it.tag == channelTag && it.id != notificationId
                }

                PersistentLog.d(context, Constants.logTag, "Found ${leftoverNotifications.size} leftover notifications after deleting ID $notificationId")

                // If there are no non-summary notifications left, or only the summary notification (ID = 0) remains,
                // we should cancel the summary notification
                val nonSummaryNotifications = leftoverNotifications.filter { it.id != 0 }
                if (nonSummaryNotifications.isEmpty()) {
                    PersistentLog.d(context, Constants.logTag, "No non-summary notifications remaining, cancelling notification summary")
                    notificationManager.cancel(channelTag, 0)
                }
            }
        } catch (exception: Exception) {
            PersistentLog.e(context, Constants.logTag, "Failed to cancel notification with ID $notificationId!", exception)
            return false
        }
        
        return true
    }

    // Cancelling a bubble's notification removes the bubble, so take it out of the shade instead.
    private fun hideBubbledNotification(context: Context, notificationManager: NotificationManager, sbn: StatusBarNotification): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        val current = sbn.notification
        val bubble = current.bubbleMetadata ?: return false
        if (current.flags and Notification.FLAG_BUBBLE == 0) return false

        val shortcutId = bubble.shortcutId
        val intent = bubble.intent
        val icon = bubble.icon
        val builder = when {
            shortcutId != null -> Notification.BubbleMetadata.Builder(shortcutId)
            intent != null && icon != null -> Notification.BubbleMetadata.Builder(intent, icon)
            else -> return false
        }
        if (bubble.desiredHeightResId != 0) builder.setDesiredHeightResId(bubble.desiredHeightResId)
        else builder.setDesiredHeight(bubble.desiredHeight)
        builder.setDeleteIntent(bubble.deleteIntent).setSuppressNotification(true)

        val hidden = Notification.Builder.recoverBuilder(context, current)
            .setBubbleMetadata(builder.build())
            .setOnlyAlertOnce(true)
            .build()
        notificationManager.notify(sbn.tag, sbn.id, hidden)
        return true
    }
}