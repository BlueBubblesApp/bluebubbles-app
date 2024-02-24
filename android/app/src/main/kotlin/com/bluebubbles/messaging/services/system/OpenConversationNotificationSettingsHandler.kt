package com.bluebubbles.messaging.services.system

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Open/Create the conversation-specific notification settings
class OpenConversationNotificationSettingsHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "open-conversation-notification-settings"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        // check if we are on a lower SDK
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error("500", "Cannot create chat notification settings below Android R!", null)
            return
        }
        val notificationManager: NotificationManager = context.getSystemService(NotificationManager::class.java)
        val channelName: String = call.argument("display_name")!!
        val channelId: String = call.argument("channel_id")!!
        // We don't check if the channel exists because the underlying new messages channel gets returned then
        Log.d(Constants.logTag, "Creating channel...")
        // setup channel with parameters
        val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH)
        // set the channel to allow bubbling, bypassing DND, and showing badges
        channel.setAllowBubbles(true)
        channel.setBypassDnd(true)
        channel.setShowBadge(true)
        channel.setConversationId("com.bluebubbles.new_messages", channelId);
        // create the channel
        notificationManager.createNotificationChannel(channel)
        // create the intent and launch
        Log.d(Constants.logTag, "Launching notification settings for conversation")
        val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .putExtra(Settings.EXTRA_CHANNEL_ID, channel.id)
            .putExtra(Settings.EXTRA_CONVERSATION_ID, channel.conversationId)
            .putExtra("finishActivityOnSaveCompleted", true)
        context.startActivity(intent)
        result.success(null)
    }
}