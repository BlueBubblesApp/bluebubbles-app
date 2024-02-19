package com.bluebubbles.messaging.services.notifications

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.MainActivity
import com.bluebubbles.messaging.R
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.services.intents.InternalIntentReceiver
import com.bluebubbles.messaging.utils.Utils
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CreateIncomingFaceTimeNotification: MethodCallHandlerImpl() {
    companion object {
        const val tag = "create-incoming-facetime-notification"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        // channel details
        val channelId: String = call.argument("channel_id")!!
        val notificationId: Int = call.argument("notification_id")!!
        // call details
        val callUuid: String? = call.argument("call_uuid")
        val title: String = call.argument("title")!!
        val body: String = call.argument("body")!!
        // contact details
        val callerName: String = call.argument("caller")!!
        val callerIcon: ByteArray? = call.argument("caller_avatar")
        val callerBitmap = if ((callerIcon?.size ?: 0) == 0) null else BitmapFactory.decodeByteArray(callerIcon!!, 0, callerIcon.size)
        val callerIconCompat = if ((callerIcon?.size ?: 0) == 0) null else Utils.getAdaptiveIconFromByteArray(callerIcon!!)

        // build the caller object
        val caller = Person.Builder()
            .setName(callerName)
            .setIcon(callerIconCompat)
            .setImportant(true)
            .build()

        // create a bundle for extra info
        val extras = Bundle()
        extras.putString("callUuid", callUuid)

        // intent to open the app
        val openSummaryIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .putExtras(extras)
                .putExtra("answer", false)
                .putExtra("caller", callerName)
                .setType("OpenSummary"),
            PendingIntent.FLAG_IMMUTABLE
        )

        // Create intent for answering and opening the facetime link
        val answerIntent = PendingIntent.getActivity(
            context,
            notificationId + Constants.pendingIntentAnswerFaceTimeOffset,
            Intent(context, MainActivity::class.java)
                .putExtras(extras)
                .putExtra("answer", true)
                .putExtra("caller", callerName)
                .setType("AnswerFaceTime"),
            PendingIntent.FLAG_IMMUTABLE
        )
        val answerAction = NotificationCompat.Action.Builder(0, "Answer", answerIntent)
            .setShowsUserInterface(false)
            .build()

        // Create intent for declining the facetime
        val declineIntent = PendingIntent.getBroadcast(
            context,
            notificationId + Constants.pendingIntentDeclineFaceTimeOffset,
            Intent(context, InternalIntentReceiver::class.java)
                .putExtra("notificationId", notificationId)
                .setType("DeleteNotification"),
            PendingIntent.FLAG_IMMUTABLE
        )
        val declineAction = NotificationCompat.Action.Builder(0, "Ignore", declineIntent)
            .setShowsUserInterface(false)
            .build()

        val notificationBuilder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_stat_icon)
            .setAutoCancel(true)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setContentTitle(title)
            .setContentText(body)
            .addExtras(extras)
            .addPerson(caller)
            .setColor(4888294)
            .addAction(answerAction)
            .addAction(declineAction)
            .extend(NotificationCompat.WearableExtender().addAction(answerAction).addAction(declineAction))
        if (callerBitmap != null) {
            notificationBuilder.setLargeIcon(callerBitmap)
        }
        if (callUuid != null) {
            notificationBuilder.setContentIntent(openSummaryIntent);
            // clear after 30 seconds in case we didn't get an event from the server
            notificationBuilder.setTimeoutAfter(30000);
        }

        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager.notify(Constants.newFaceTimeNotificationTag, notificationId, notificationBuilder.build())
        result.success(null)
    }
}