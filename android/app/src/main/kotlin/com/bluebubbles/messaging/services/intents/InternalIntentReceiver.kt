package com.bluebubbles.messaging.services.intents

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.services.backend_ui_interop.DartWorkManager
import com.bluebubbles.messaging.services.network.HttpService
import com.bluebubbles.messaging.services.notifications.DeleteNotificationHandler
import com.bluebubbles.messaging.utils.PersistentLog
import com.bluebubbles.messaging.utils.Utils
import java.io.BufferedInputStream
import java.io.DataInputStream
import java.io.File
import java.io.FileInputStream
import java.io.IOException


class InternalIntentReceiver: BroadcastReceiver() {
    @SuppressLint("NewApi")
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        PersistentLog.d(context, Constants.logTag, "Received internal intent ${intent.type}, handling...")
        when (intent.type) {
            "DeleteNotification" -> {
                val notificationId: Int = intent.getIntExtra("notificationId", 0)
                val tag: String? = intent.getStringExtra("tag")
                DeleteNotificationHandler().deleteNotification(context, notificationId, tag)
            }
            "MarkChatRead" -> {
                val notificationId: Int = intent.getIntExtra("notificationId", 0)
                val chatGuid: String? = intent.getStringExtra("chatGuid")
                val tag: String? = intent.getStringExtra("tag")
                DeleteNotificationHandler().deleteNotification(context, notificationId, tag)
                DartWorkManager.createWorker(context, intent.type!!, hashMapOf("chatGuid" to chatGuid)) {}
            }
            "ReplyChat" -> {
                val notificationId: Int = intent.getIntExtra("notificationId", 0)
                val chatGuid: String? = intent.getStringExtra("chatGuid")
                val messageGuid: String? = intent.getStringExtra("messageGuid")
                val replyText = RemoteInput.getResultsFromIntent(intent)?.getString("text_reply") ?: return

                DartWorkManager.createWorker(context, intent.type!!, hashMapOf("chatGuid" to chatGuid, "messageGuid" to messageGuid, "text" to replyText)) {
                    val notificationManager = context.getSystemService(NotificationManager::class.java)
                    // this is used to copy the style, since the notification already exists
                    PersistentLog.d(context, Constants.logTag, "Fetching existing notification values")
                    val chatNotification = notificationManager.activeNotifications.lastOrNull { it.id == notificationId }
                    if (chatNotification == null) {
                        PersistentLog.e(context, Constants.logTag, "Could not find notification with ID $notificationId")
                        return@createWorker
                    }
                    val oldBuilder = Notification.Builder.recoverBuilder(context, chatNotification.notification)
                    val oldStyle = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        oldBuilder.style as? Notification.MessagingStyle
                    } else {
                        val temp = NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(chatNotification.notification)
                        if (temp != null) {
                            Notification.MessagingStyle(Person.Builder()
                                .setName(temp.user.name)
                                .setIcon(temp.user.icon?.toIcon(context))
                                .build()
                            )
                        } else null
                    }

                    PersistentLog.d(context, Constants.logTag, "Creating sender and message object for the user-created reply")
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", 0)

                    // If we couldn't extract the old style, create a new one so the user still sees their reply
                    val messagingStyle = oldStyle ?: run {
                        PersistentLog.w(context, Constants.logTag, "Could not extract MessagingStyle, creating new one for reply")
                        Notification.MessagingStyle(Person.Builder()
                            .setName(prefs.getString("userName", "You"))
                            .build()
                        )
                    }
                    val sender = Person.Builder()
                        .setName(prefs.getString("userName", "You"))
                    val avatarPath = prefs.getString("userAvatarPath", "")
                    if (avatarPath!!.isNotEmpty()) {
                        val file = File(avatarPath)
                        val bytes = ByteArray(file.length().toInt())
                        try {
                            val bis = BufferedInputStream(FileInputStream(file))
                            val dis = DataInputStream(bis)
                            dis.readFully(bytes)
                            sender.setIcon(Utils.getAdaptiveIconFromByteArray(bytes).toIcon(context))
                        } catch (e: IOException) {
                            e.printStackTrace()
                        }
                    }
                    messagingStyle.addMessage(Notification.MessagingStyle.Message(
                        replyText,
                        System.currentTimeMillis(),
                        sender.build()
                    ))

                    PersistentLog.d(context, Constants.logTag, "Posting the user-created reply")
                    oldBuilder.setStyle(messagingStyle)
                    oldBuilder.setOnlyAlertOnce(true)
                    oldBuilder.setGroupAlertBehavior(Notification.GROUP_ALERT_SUMMARY)
                    notificationManager.notify(Constants.newMessageNotificationTag, notificationId, oldBuilder.build())
                }
            }
            "LikeMessage" -> {
                val notificationId: Int = intent.getIntExtra("notificationId", 0)
                val chatGuid: String? = intent.getStringExtra("chatGuid")
                val messageGuid: String? = intent.getStringExtra("messageGuid")
                val messageText: String? = intent.getStringExtra("messageText")
                val reactionType: String = intent.getStringExtra("reactionType") ?: "like"
                val tag: String? = intent.getStringExtra("tag")
                val channelId: String? = intent.getStringExtra("channelId")
                val reactionSent: Boolean = intent.getBooleanExtra("reactionSent", false)
                
                if (chatGuid.isNullOrEmpty() || messageGuid.isNullOrEmpty() || messageText.isNullOrEmpty()) {
                    PersistentLog.e(context, Constants.logTag, "Missing required parameters for LikeMessage")
                    return
                }
                
                // Show "Sending..." while processing
                updateReactionButton(
                    context, 
                    notificationId, 
                    chatGuid, 
                    messageGuid, 
                    messageText, 
                    reactionType, 
                    reactionSent,
                    channelId,
                    tag,
                    buttonText = "Sending..."
                )
                
                // Use the new HttpService to send the tapback without Flutter engine
                // If reaction was already sent, prefix with "-" to remove it
                val reactionToSend = if (reactionSent) "-$reactionType" else reactionType
                val httpService = HttpService(context)
                httpService.sendTapback(
                    chatGuid = chatGuid,
                    selectedMessageText = messageText,
                    selectedMessageGuid = messageGuid,
                    reaction = reactionToSend,
                    onSuccess = { response ->
                        val actionName = if (reactionSent) "removed" else "sent"
                        PersistentLog.i(context, Constants.logTag, "Reaction ($reactionToSend) $actionName successfully")
                        
                        // Update the notification to toggle the button label
                        updateReactionButton(
                            context, 
                            notificationId, 
                            chatGuid, 
                            messageGuid, 
                            messageText, 
                            reactionType, 
                            !reactionSent,
                            channelId,
                            tag
                        )
                    },
                    onError = { error ->
                        PersistentLog.e(context, Constants.logTag, "Failed to send reaction: $error")
                        
                        // Show error state, then revert after a delay
                        updateReactionButton(
                            context, 
                            notificationId, 
                            chatGuid, 
                            messageGuid, 
                            messageText, 
                            reactionType, 
                            reactionSent,
                            channelId,
                            tag,
                            buttonText = "Error - Retry"
                        )
                    }
                )
            }
        }
    }

    private fun updateReactionButton(
        context: Context,
        notificationId: Int,
        chatGuid: String,
        messageGuid: String,
        messageText: String,
        reactionType: String,
        reactionSent: Boolean,
        channelId: String?,
        tag: String?,
        buttonText: String? = null
    ) {
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        
        // Get the existing notification
        val existingNotification = notificationManager.activeNotifications.firstOrNull { 
            it.id == notificationId && it.tag == tag 
        } ?: return
        
        // Rebuild the notification with updated action
        val oldBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Notification.Builder.recoverBuilder(context, existingNotification.notification)
        } else {
            return // Can't update on older versions
        }
        
        // Create new extras with updated reaction state
        val extras = Bundle()
        extras.putString("chatGuid", chatGuid)
        extras.putString("messageGuid", messageGuid)
        extras.putString("channelId", channelId)
        extras.putString("tag", tag)
        extras.putBoolean("reactionSent", reactionSent)
        
        // Create the updated reaction intent
        val likeIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 1,
            Intent(context, InternalIntentReceiver::class.java)
                .putExtras(extras)
                .putExtra("notificationId", notificationId)
                .putExtra("messageText", messageText)
                .putExtra("reactionType", reactionType)
                .putExtra("reactionSent", reactionSent)
                .setType("LikeMessage"),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        // Update button label based on state
        val actionTitle = buttonText ?: when {
            reactionType == "love" && reactionSent -> "Un-Love"
            reactionType == "love" && !reactionSent -> "Love"
            reactionType == "like" && reactionSent -> "Un-Like"
            else -> "Like"
        }
        
        val likeAction = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Notification.Action.Builder(
                null,
                actionTitle,
                likeIntent
            ).build()
        } else {
            return
        }
        
        // Clear existing actions and rebuild
        oldBuilder.setActions()
        
        // Re-add mark as read action (get from original notification if possible)
        val markAsReadIntent = PendingIntent.getBroadcast(
            context,
            notificationId + Constants.pendingIntentMarkReadOffset,
            Intent(context, InternalIntentReceiver::class.java)
                .putExtras(extras)
                .putExtra("notificationId", notificationId)
                .setType("MarkChatRead"),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val markAsReadAction = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Notification.Action.Builder(null, "Mark As Read", markAsReadIntent).build()
        } else {
            return
        }
        
        // Re-add reply action
        val replyIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            Intent(context, InternalIntentReceiver::class.java)
                .putExtras(extras)
                .putExtra("notificationId", notificationId)
                .setType("ReplyChat"),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val remoteInput = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            android.app.RemoteInput.Builder("text_reply").setLabel("Reply").build()
        } else {
            return
        }
        
        val replyAction = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Notification.Action.Builder(null, "Reply", replyIntent)
                .addRemoteInput(remoteInput)
                .build()
        } else {
            return
        }
        
        oldBuilder.addAction(markAsReadAction)
        oldBuilder.addAction(replyAction)
        oldBuilder.addAction(likeAction)
        
        // Post the updated notification
        oldBuilder.setOnlyAlertOnce(true)
        notificationManager.notify(tag, notificationId, oldBuilder.build())
    }
}