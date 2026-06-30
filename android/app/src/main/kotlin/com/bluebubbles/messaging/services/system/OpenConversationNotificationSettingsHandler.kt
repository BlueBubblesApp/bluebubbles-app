package com.bluebubbles.messaging.services.system

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.utils.ContactNotificationHelper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Open notification settings for a conversation (uses the global New Messages channel).
class OpenConversationNotificationSettingsHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "open-conversation-notification-settings"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error("500", "Cannot create chat notification settings below Android R!", null)
            return
        }
        val chatGuid: String = call.argument("channel_id")!!
        val channelId = ContactNotificationHelper.PARENT_CHANNEL_ID
        val notificationManager: NotificationManager = context.getSystemService(NotificationManager::class.java)
        if (notificationManager.getNotificationChannel(channelId) == null) {
            result.error("500", "New Messages notification channel does not exist", null)
            return
        }
        Log.d(Constants.logTag, "Launching notification settings for conversation on $channelId")
        val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
            .putExtra(Settings.EXTRA_CONVERSATION_ID, chatGuid)
            .putExtra("finishActivityOnSaveCompleted", true)
        context.startActivity(intent)
        result.success(null)
    }
}