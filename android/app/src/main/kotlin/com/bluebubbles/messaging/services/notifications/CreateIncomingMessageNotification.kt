package com.bluebubbles.messaging.services.notifications

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.app.RemoteInput
import androidx.core.graphics.drawable.IconCompat
import com.bluebubbles.messaging.BubbleActivity
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.MainActivity
import com.bluebubbles.messaging.R
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.services.intents.InternalIntentReceiver
import com.bluebubbles.messaging.services.system.PushShareTargetsHandler
import com.bluebubbles.messaging.utils.ContactNotificationHelper
import com.bluebubbles.messaging.utils.Utils
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CreateIncomingMessageNotification: MethodCallHandlerImpl() {
    companion object {
        const val tag = "create-incoming-message-notification"
        private val notificationLock = Any()
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        // channel details
        val channelId: String = call.argument("channel_id")!!
        // chat details
        val chatGuid: String = call.argument("chat_guid")!!
        val chatTitle: String = call.argument("chat_title")!!
        val chatIsGroup: Boolean = call.argument("chat_is_group")!!
        val chatIcon: ByteArray? = call.argument("chat_icon")
        val chatBitmap = if ((chatIcon?.size ?: 0) == 0) null else Utils.getAdaptiveIconFromByteArray(chatIcon!!)
        // message details
        val messageText: String = call.argument("message_text")!!
        val messageGuid: String = call.argument("message_guid")!!
        val messageDate: Long = call.argument("message_date")!!
        val messageIsFromMe: Boolean = call.argument("message_is_from_me")!!
        // contact details
        val contactName: String = call.argument("contact_name")!!
        val contactIcon: ByteArray? = call.argument("contact_avatar")
        val contactBitmap = if ((contactIcon?.size ?: 0) == 0) null else Utils.getAdaptiveIconFromByteArray(contactIcon!!)
        val nativeContactId: String? = call.argument("native_contact_id")
        val dndFavoritesOverride: Boolean = call.argument<Boolean>("dnd_favorites_override") ?: false
        // reaction settings
        val showReactionAction: Boolean = call.argument("show_reaction_action") ?: false
        val reactionType: String = call.argument("reaction_type") ?: "like"

        // calculate a notification ID based on the chat database ID
        val notificationId: Int = call.argument("chat_id")!!

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        
        // Synchronize to prevent duplicate notifications from concurrent calls
        synchronized(notificationLock) {
            // check if the message has already been posted as a notification
            val notificationPostedAlready = notificationManager.activeNotifications.firstOrNull { it.notification.extras.getString("chatGuid") == chatGuid && it.notification.extras.getString("messageGuid") == messageGuid } != null
            // don't double post a notification
            if (notificationPostedAlready) return result.success(null)
        }
        
        // this is used to copy the style, since the notification already exists
        val chatNotification = notificationManager.activeNotifications.lastOrNull { it.notification.extras.getString("chatGuid") == chatGuid && it.notification.extras.getString("channelId") == channelId }

        // Build the sender Person and push the share target. When "Override DND for Favorites"
        // is on, resolve the contact once and grant starred contacts a per-contact DND exception
        // via the Person lookup URI; otherwise no contact link and no DND bypass.
        val contactInfo = if (dndFavoritesOverride) {
            ContactNotificationHelper.resolveContactInfo(context, nativeContactId)
        } else {
            ContactNotificationHelper.ContactInfo(lookupUri = null, isFavorite = false)
        }
        val sender = ContactNotificationHelper.buildPerson(contactName, contactBitmap, contactInfo)
        PushShareTargetsHandler().pushShareTarget(context, chatTitle, chatGuid, chatIcon, contactInfo)

        // get or create a messaging style
        val style = if (chatNotification != null) {
            NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(chatNotification.notification)
                ?: NotificationCompat.MessagingStyle(Person.Builder().setName("You").build())
        } else {
            NotificationCompat.MessagingStyle(Person.Builder().setName("You").build())
        }
        if (chatIsGroup) {
            style.isGroupConversation = true
            style.conversationTitle = chatTitle
        }
        // add the new message to the style
        style.addMessage(NotificationCompat.MessagingStyle.Message(
            messageText,
            messageDate,
            sender
        ))

        // create a bundle for extra info
        val extras = Bundle()
        extras.putString("chatGuid", chatGuid)
        extras.putString("messageGuid", messageGuid)
        extras.putString("channelId", channelId)
        extras.putString("tag", Constants.newMessageNotificationTag)
        extras.putBoolean("reactionSent", false) // Track if reaction has been sent

        // intent to open the conversation in-app
        val openConversationIntent = PendingIntent.getActivity(
            context,
            notificationId + Constants.pendingIntentOpenChatOffset,
            Intent(context, MainActivity::class.java)
                .putExtras(extras)
                .putExtra("notificationId", notificationId)
                .putExtra("bubble", false)
                .setType("OpenChat"),
            PendingIntent.FLAG_IMMUTABLE
        )

        // intent to swipe away the notification
        val deleteNotificationIntent = PendingIntent.getBroadcast(
            context,
            notificationId + Constants.pendingIntentDeleteNotificationOffset,
            Intent(context, InternalIntentReceiver::class.java)
                .putExtras(extras)
                .putExtra("notificationId", notificationId)
                .setType("DeleteNotification"),
            PendingIntent.FLAG_IMMUTABLE
        )

        // intent and action for 'mark as read'
        val markAsReadIntent = PendingIntent.getBroadcast(
            context,
            notificationId + Constants.pendingIntentMarkReadOffset,
            Intent(context, InternalIntentReceiver::class.java)
                .putExtras(extras)
                .putExtra("notificationId", notificationId)
                .setType("MarkChatRead"),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val markAsReadAction = NotificationCompat.Action.Builder(0, "Mark As Read", markAsReadIntent)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_MARK_AS_READ)
            .setShowsUserInterface(false)
            .build()

        // intent and action for quick reply
        val replyIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            Intent(context, InternalIntentReceiver::class.java)
                .putExtras(extras)
                .putExtra("notificationId", notificationId)
                .setType("ReplyChat"),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val replyAction = NotificationCompat.Action.Builder(0, "Reply", replyIntent)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
            .setShowsUserInterface(false)
            .setAllowGeneratedReplies(true)
            .extend(NotificationCompat.Action.WearableExtender().setHintDisplayActionInline(true))
            .addRemoteInput(RemoteInput.Builder("text_reply").setLabel("Reply").build())
            .build()

        // intent and action for 'like'
        val likeIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 1, // offset by 1 to avoid conflicts
            Intent(context, InternalIntentReceiver::class.java)
                .putExtras(extras)
                .putExtra("notificationId", notificationId)
                .putExtra("messageText", messageText)
                .putExtra("reactionType", reactionType)
                .setType("LikeMessage"),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val likeActionTitle = if (reactionType == "love") "Love" else "Like"
        val likeAction = NotificationCompat.Action.Builder(0, likeActionTitle, likeIntent)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_THUMBS_UP)
            .setShowsUserInterface(false)
            .build()

        // intent for bubbling (create it even if not used, for future compatibility)
        val bubbleIntent = PendingIntent.getActivity(
            context,
            notificationId + Constants.pendingIntentOpenBubbleOffset,
            Intent(context, BubbleActivity::class.java)
                .putExtras(extras)
                .putExtra("notificationId", notificationId)
                .putExtra("bubble", true)
                .setType("OpenChat"),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Build the notification
        val notificationBuilder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_stat_icon)
            .setGroup(Constants.notificationGroupKey)
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)
            .setOnlyAlertOnce(messageIsFromMe)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setContentIntent(openConversationIntent)
            .setDeleteIntent(deleteNotificationIntent)
            .setStyle(style)
            .setAllowSystemGeneratedContextualActions(true)
            .setColor(4888294)
            .addAction(markAsReadAction)
            .addAction(replyAction)
            .addPerson(sender)
            .addExtras(extras)

        // Conditionally add reaction action if enabled
        if (showReactionAction) {
            notificationBuilder.addAction(likeAction)
        }

        // Build wearable extender
        val wearableExtender = NotificationCompat.WearableExtender()
            .addAction(markAsReadAction)
            .addAction(replyAction)
        if (showReactionAction) {
            wearableExtender.addAction(likeAction)
        }
        notificationBuilder.extend(wearableExtender)

        // Only set bubble metadata on Android 11+ (API 29+) where it's supported
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val bubbleMetadata = NotificationCompat.BubbleMetadata.Builder(bubbleIntent, chatBitmap ?: IconCompat.createWithResource(context, R.mipmap.ic_stat_icon))
                .setDesiredHeight(600)
                .setDeleteIntent(deleteNotificationIntent)
                .build()
            notificationBuilder.setBubbleMetadata(bubbleMetadata)
        }
        
        // Only set shortcut ID on API 29+ where dynamic shortcuts are better supported
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            notificationBuilder.setShortcutId(chatGuid)
        }

        // intent to open the main app
        val openSummaryIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .putExtra("chatGuid", "-1")
                .putExtra("notificationId", 0)
                .putExtra("bubble", false)
                .setType("OpenSummary"),
            PendingIntent.FLAG_IMMUTABLE
        )

        val summaryNotificationBuilder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_stat_icon)
            .setGroup(Constants.notificationGroupKey)
            .setGroupSummary(true)
            .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setContentIntent(openSummaryIntent)
            .setColor(4888294)

        notificationManager.notify(Constants.newMessageNotificationTag, 0, summaryNotificationBuilder.build())
        notificationManager.notify(Constants.newMessageNotificationTag, notificationId, notificationBuilder.build())
        result.success(null)
    }
}