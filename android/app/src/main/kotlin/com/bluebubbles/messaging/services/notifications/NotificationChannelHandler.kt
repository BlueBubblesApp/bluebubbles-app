package com.bluebubbles.messaging.services.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NotificationChannelHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "create-notification-channel"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        // check if we are on a lower SDK
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(null)
            return
        }
        val notificationManager: NotificationManager = context.getSystemService(NotificationManager::class.java)
        val channelName: String = call.argument("channel_name")!!
        val channelDescription: String = call.argument("channel_description")!!
        val channelId: String = call.argument("channel_id")!!
        Log.d(Constants.logTag, "Creating channel with name $channelName")
        // check if the channel exists
        if (notificationManager.getNotificationChannel(channelId) != null) {
            Log.d(Constants.logTag, "Notification channel already exists! Ignoring...")
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
        // set 'Foreground Service' channel to low importance (avoid heads-up notification)
        } else if (channelId == "com.bluebubbles.foreground_service") {
            channel.importance = NotificationManager.IMPORTANCE_LOW
        }
        // create the channel
        notificationManager.createNotificationChannel(channel)
    }
}