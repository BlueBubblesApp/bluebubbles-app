package com.bluebubbles.messaging.method_call_handler.handlers;

import android.annotation.SuppressLint;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Person;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.os.Bundle;
import android.service.notification.StatusBarNotification;

import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.graphics.drawable.IconCompat;

import com.bluebubbles.messaging.MainActivity;
import com.bluebubbles.messaging.R;
import com.bluebubbles.messaging.helpers.HelperUtils;
import com.bluebubbles.messaging.services.ReplyReceiver;
import com.bluebubbles.messaging.sharing.Contact;
import com.bluebubbles.messaging.sharing.ShareShortcutManager;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class NewMessageNotification implements Handler {
    public static String TAG = "new-message-notification";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public NewMessageNotification(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @SuppressLint("RestrictedApi")
    @RequiresApi(api = Build.VERSION_CODES.P)
    @Override
    public void Handle() {
        // Find any notifications that match the same chat
        NotificationCompat.MessagingStyle style = null;
        NotificationManager notificationManager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
        int existingNotificationId = 0;
        for (StatusBarNotification notification : notificationManager.getActiveNotifications()) {
            String chatGuid = notification.getNotification().extras.getString("chatGuid");

            if (chatGuid != null && chatGuid.equals(call.argument("group"))) {
                existingNotificationId = notification.getId();
                style = NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(notification.getNotification());
                break;
            }
        }

        // Set the style based on if there is already a matching notification
        if (style == null) {
            androidx.core.app.Person myPerson = androidx.core.app.Person.fromAndroidPerson(
                new Person.Builder()
                    .setName("You")
                    .setImportant(true)
                    .build()
            );
            style = new NotificationCompat.MessagingStyle(myPerson);
            if (call.argument("groupConversation")) {
                style.setConversationTitle(call.argument("contentTitle"));
            }

            style.setGroupConversation(call.argument("groupConversation"));
        }

        // Get the current timestamp
        Long timestamp;
        if (call.argument("timeStamp").getClass() == Long.class) {
            timestamp = call.argument("timeStamp");
        } else if (call.argument("timeStamp").getClass() == Integer.class) {
            timestamp = Long.valueOf(((Integer) call.argument("timeStamp")).longValue());
        } else {
            timestamp = Long.valueOf(call.argument("timeStamp"));
        }

        // Build the sender icon
        IconCompat icon = null;
        if (call.argument("contactIcon") != null) {
            Bitmap bmp = BitmapFactory.decodeByteArray((byte[]) call.argument("contactIcon"), 0, ((byte[]) call.argument("contactIcon")).length);
            icon = IconCompat.createWithAdaptiveBitmap(HelperUtils.getCircleBitmap(bmp));
        }

        Person.Builder person = new Person.Builder()
            .setName(call.argument("name"))
            .setImportant(true);
        if (icon != null) {
            person.setIcon(icon.toIcon());
        }

        // Add the message to the notification
        style.addMessage(new NotificationCompat.MessagingStyle.Message(
                call.argument("contentText"),
                timestamp,
                androidx.core.app.Person.fromAndroidPerson(person.build())
        ));
        Bundle extras = new Bundle();
        extras.putCharSequence("chatGuid", call.argument("group"));

        if (existingNotificationId == 0) {
            existingNotificationId = call.argument("notificationId");
        }

        // Create intent for opening the conversation in the app
        PendingIntent openIntent = PendingIntent.getActivity(
                context,
                existingNotificationId,
                new Intent(context, MainActivity.class)
                        .putExtra("id", existingNotificationId)
                        .putExtra("chatGUID",
                                (String) call.argument("group"))
                        .putExtra("bubble", true)
                        .setType("NotificationOpen"),
                Intent.FILL_IN_ACTION);

        // Create intent for dismissing the notification
        PendingIntent dismissIntent = PendingIntent.getBroadcast(
                context,
                existingNotificationId,
                new Intent(context, ReplyReceiver.class)
                        .putExtra("id", existingNotificationId)
                        .putExtra("chatGuid",
                                (String) call.argument("group")).setType("markAsRead"),
                PendingIntent.FLAG_UPDATE_CURRENT);
        NotificationCompat.Action dismissAction = new NotificationCompat.Action.Builder(0, "Mark As Read", dismissIntent).build();

        // Create intent for quick reply
        Intent intent = new Intent(context, ReplyReceiver.class)
                .putExtra("id", existingNotificationId)
                .putExtra("chatGuid", (String) call.argument("group"))
                .putExtra("channelName", (String) call.argument("CHANNEL_NAME"))
                .putExtra("channelID", (String) call.argument("CHANNEL_ID"))
                .setType("reply");
        PendingIntent replyIntent = PendingIntent.getBroadcast(context, existingNotificationId, intent, PendingIntent.FLAG_UPDATE_CURRENT);
        androidx.core.app.RemoteInput replyInput = new androidx.core.app.RemoteInput.Builder("key_text_reply").setLabel("Reply").build();
        NotificationCompat.Action replyAction = new NotificationCompat.Action.Builder(0, "Reply", replyIntent)
                .addRemoteInput(replyInput)
                .setAllowGeneratedReplies(true)
                .extend(new NotificationCompat.Action.WearableExtender()
                        .setHintDisplayActionInline(true))
                .build();

        // // Build the metadata
        // NotificationCompat.BubbleMetadata.Builder bubbleMetadata = new NotificationCompat.BubbleMetadata.Builder()
        //     .setIntent(openIntent)
        //     .setDesiredHeight(600)
        //     .setAutoExpandBubble(true)
        //     .setSuppressNotification(false);

        // // Dynamically set the icon
        // NotificationCompat.BubbleMetadata bubbleData = null;
        // if (icon != null) {
        //     bubbleMetadata.setIcon(icon);
        //     bubbleData = bubbleMetadata.build();
        // }

        // Build the actual notification
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, (String) call.argument("CHANNEL_ID"))
                .setSmallIcon(R.mipmap.ic_stat_icon)
                .setAllowSystemGeneratedContextualActions(true)
                .setAutoCancel(true)
                // Tell android that it's a message/conversation
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                // Set the priority to high since it's a message they should see
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(openIntent)
                .addAction(dismissAction)
                .addAction(replyAction)
                .setStyle(style)
                .setShortcutId(call.argument("group"))
                .addExtras(extras)
                // .setBubbleMetadata(bubbleData)
                .setColor(4888294);

        // Send the notification
        NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);
        notificationManagerCompat.notify(existingNotificationId, builder.build());
        result.success("");
    }
}
