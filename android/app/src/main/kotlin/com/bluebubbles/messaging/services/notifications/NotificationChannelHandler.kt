package com.bluebubbles.messaging.services.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.utils.PersistentLog
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NotificationChannelHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "create-notification-channel"
        private const val PREFS_NAME = "notification_channel_prefs"
        private const val KEY_NEW_MESSAGES_VIBRATION_MIGRATED = "new_messages_vibration_migrated"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        try {
            // check if we are on a lower SDK
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                result.success(null)
                return
            }
            val notificationManager: NotificationManager = context.getSystemService(NotificationManager::class.java)
            val channelName: String = call.argument("channel_name")!!
            val channelDescription: String = call.argument("channel_description")!!
            val channelId: String = call.argument("channel_id")!!
            PersistentLog.d(context, Constants.logTag, "Creating channel with name $channelName")
            
            // Perform a one-time migration for the 'New Messages' channel.
            // This is because previously, enableVibration wasn't explicitly set to true.
            // As a result, the notification channel was not vibrating on some devices by default.
            // To fix this, we check if the channel already exists without vibration, and then
            // perform a one-time migration to remediate that. Some devices will always report
            // shouldVibrate() as false, so we also use SharedPreferences to ensure we only do this once.
            if (channelId == "com.bluebubbles.new_messages") {
                val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val alreadyMigrated = prefs.getBoolean(KEY_NEW_MESSAGES_VIBRATION_MIGRATED, false)
                val existing = notificationManager.getNotificationChannel(channelId)
                if (existing != null && !existing.shouldVibrate() && !alreadyMigrated) {
                    PersistentLog.d(context, Constants.logTag, "New messages channel exists without vibration, recreating once")
                    notificationManager.deleteNotificationChannel(channelId)
                    prefs.edit().putBoolean(KEY_NEW_MESSAGES_VIBRATION_MIGRATED, true).apply()
                } else if (existing != null) {
                    if (!alreadyMigrated) {
                        prefs.edit().putBoolean(KEY_NEW_MESSAGES_VIBRATION_MIGRATED, true).apply()
                    }
                    PersistentLog.d(context, Constants.logTag, "Notification channel already exists! Ignoring...")
                    result.success(null)
                    return
                }
            } else if (notificationManager.getNotificationChannel(channelId) != null) {
                PersistentLog.d(context, Constants.logTag, "Notification channel already exists! Ignoring...")
                result.success(null)
                return
            }

            // setup channel with parameters
            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH)
            channel.description = channelDescription
            // set the 'New Messages' channel to allow bubbling, bypassing DND, and showing badges
            if (channelId == "com.bluebubbles.new_messages") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    channel.setAllowBubbles(true)
                }
                channel.setBypassDnd(true)
                channel.setShowBadge(true)
                channel.enableVibration(true)
            // set 'Foreground Service' channel to low importance (avoid heads-up notification)
            } else if (channelId == "com.bluebubbles.foreground_service") {
                channel.importance = NotificationManager.IMPORTANCE_LOW
            }
            // create the channel
            notificationManager.createNotificationChannel(channel)
            result.success(null)
        } catch (e: Exception) {
            PersistentLog.e(context, Constants.logTag, "Failed to create notification channel", e)
            result.error("500", "Failed to create notification channel", e.message)
        }
    }
}