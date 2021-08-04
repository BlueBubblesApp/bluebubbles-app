package com.bluebubbles.messaging.method_call_handler.handlers;

import android.util.Log;
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
        // Information we need from Dart code
        // - Chat GUID
        // - Chat.isGroup
        // - Chat Title / Name
        // - Contact Name
        // - Contact Avatar
        // - Message Text
        // - Message.isFromMe
        // - Message.dateCreated
        // - Chat Icon (Group chat icon)
        // - Notification visibility

        // These are new, not yet implemented on the Dart side
        // Channel stuff
        String channelId = (String) call.argument("CHANNEL_ID");
        String channelName = (String) call.argument("CHANNEL_NAME");

        // Chat stuff
        String chatGuid = (String) call.argument("chatGuid");
        Boolean chatIsGroup = (Boolean) call.argument("chatIsGroup");
        String chatTitle = (String) call.argument("chatTitle");
        byte[] chatIcon = (byte[]) call.argument("chatIcon");

        // Contact stuff
        String contactName = (String) call.argument("contactName");
        byte[] contactAvatar = (byte[]) call.argument("contactAvatar");

        // Message stuff
        String messageText = (String) call.argument("messageText");
        Integer messageDate = (Integer) call.argument("messageDate");
        Boolean messageIsFromMe = (Boolean) call.argument("messageIsFromMe");

        // Notification stuff
        Integer notificationVisibility = (Integer) call.argument("visibility");
        Integer notificationId = (Integer) call.argument("notificationId");
        Integer summaryId = (Integer) call.argument("summaryId");

        // Find any notifications that already exist for the chat
        NotificationManager notificationManager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
        Notification existingNotification;
        int existingNotificationId = notificationId;
        for (StatusBarNotification notification : notificationManager.getActiveNotifications()) {
            String existingChatGuid = notification.getNotification().extras.getString("chatGuid");
            if (existingChatGuid == null) continue;
            if (existingChatGuid.equals(chatGuid)) {
                existingNotification = notification;
                existingNotificationId = notification.getId();
                break;
            }
        }

        // Build a "Person" for the sender
        Person.Builder sender = new Person.Builder()
            .setName(contactName)
            .isBot(false)
            .setImportant(true);

        // Load the group avatar
        IconCompat senderIcon;
        if (contactAvatar != null) {
            Bitmap bmp = BitmapFactory.decodeByteArray(contactAvatar, 0, contactAvatar.length);
            senderIcon = IconCompat.createWithAdaptiveBitmap(HelperUtils.getCircleBitmap(bmp));
        }

        // Set the icon if available
        if (senderIcon != null) {
            sender.setIcon(senderIcon.toIcon());
        }

        // Create a group "person" if the chat is a group
        IconCompat groupIcon;
        Person.Builder group = new Person.Builder();
        if (chatIsGroup) {
            group.setName(chatTitle)
                .isBot(false)
                .setImportant(true);

            if (chatIcon != null) {
                Bitmap bmp = BitmapFactory.decodeByteArray(chatIcon, 0, chatIcon.length);
                groupIcon = IconCompat.createWithAdaptiveBitmap(HelperUtils.getCircleBitmap(bmp));
                group.setIcon(groupIcon.toIcon());
            }
        } else {
            // If the chat isn't a group, use the sender's info
            group = sender;
        }

        // If we have an existing style, load it
        // This will load all the other messages as part of the notification as well
        NotificationCompat.MessagingStyle style;
        if (existingNotification != null) {
            style = NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(notification.getNotification());
        } else {
            style = new NotificationCompat.MessagingStyle(group);
        }

        // Set whether the chat is a group conversation
        style.setGroupConversation(chatIsGroup);

        // Set the title of the conversation (in-case it may have changed)
        style.setConversationTitle(chatTitle);

        // Add the message to the notification
        style.addMessage(new NotificationCompat.MessagingStyle.Message(
            messageText,
            Long.valueOf(messageDate).longValue(),
            androidx.core.app.Person.fromAndroidPerson(sender.build())
        ));

        // Create a bundle with some extra information in it
        Bundle extras = new Bundle();
        extras.putCharSequence("chatGuid", chatGuid);

        // Build the base notification
        Integer visibility = Notification.VISIBILITY_PUBLIC;
        if (notificationVisibility != null) {
            visibility = notificationVisibility;
        }

        // Build the actual notification
        NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(context, channelId)
            // Set the status bar notification icon
            .setSmallIcon(R.mipmap.ic_stat_icon)
            // Let's the notification dismiss itself when it's tapped
            .setAutoCancel(true)
            // Tell android that it's a message/conversation
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            // Set the priority to high since it's a message they should see
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            // Set the visibility of the notification
            .setVisibility(visibility)
            // Sets the intent for when it's clicked
            .setContentIntent(openIntent)
            // Adds the mark as read action
            .addAction(dismissAction)
            // Adds the reply action
            .addAction(replyAction)
            // Sets the style (messages/content/etc)
            .setStyle(style)
            // Set the shortcut ID to the chat GUID since it's already unique
            .setShortcutId(chatGuid)
            // Add in any extra info we may want
            .addExtras(extras)
            // Set the color. This is the blue primary color
            .setColor(4888294);

        // Disable the alert if it's from you
        notificationBuilder.setOnlyAlertOnce(messageIsFromMe);

        // Create intent for opening the conversation in the app
        PendingIntent openIntent = PendingIntent.getActivity(
            context,
            existingNotificationId,
            new Intent(context, MainActivity.class)
                .putExtra("id", existingNotificationId)
                .putExtra("chatGuid", chatGuid)
                .putExtra("bubble", false)
                .setType("NotificationOpen"),
            Intent.FILL_IN_ACTION);

        // Create intent for dismissing the notification
        PendingIntent dismissIntent = PendingIntent.getBroadcast(
            context,
            existingNotificationId,
            new Intent(context, ReplyReceiver.class)
                .putExtra("id", existingNotificationId)
                .putExtra("chatGuid", chatGuid)
                .putExtra("bubble", false)
                .setType("markAsRead"),
            PendingIntent.FLAG_UPDATE_CURRENT);

        // Create intent for quick reply
        Intent intent = new Intent(context, ReplyReceiver.class)
            .putExtra("id", existingNotificationId)
            .putExtra("chatGuid", chatGuid)
            .putExtra("channelName", channelName)
            .putExtra("channelID", channelId)
            .putExtra("bubble", false)
            .setType("reply");

        // Create the dismiss action (mark as read)
        NotificationCompat.Action dismissAction = new NotificationCompat.Action.Builder(0, "Mark As Read", dismissIntent)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_MARK_AS_READ)
            .setShowsUserInterface(false)
            .build();

        PendingIntent replyIntent = PendingIntent.getBroadcast(context, existingNotificationId, intent, PendingIntent.FLAG_UPDATE_CURRENT);
        NotificationCompat.Action.Builder replyActionBuilder = new NotificationCompat.Action.Builder(0, "Reply", replyIntent)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
            .setShowsUserInterface(false)
            .extend(new NotificationCompat.Action.WearableExtender().setHintDisplayActionInline(true));

        // Generate contextual interactive buttons
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            replyActionBuilder.setAllowGeneratedReplies(true);
            notificationBuilder.setAllowSystemGeneratedContextualActions(true);
        }

        // Add remote input replier
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            androidx.core.app.RemoteInput replyInput = new androidx.core.app.RemoteInput.Builder("key_text_reply").setLabel("Reply").build();
            replyActionBuilder.addRemoteInput(replyInput);
        }

        // Add bubble intent handler
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            PendingIntent bubbleIntent = PendingIntent.getActivity(
                context,
                existingNotificationId,
                new Intent(context, MainActivity.class)
                    .putExtra("id", existingNotificationId)
                    .putExtra("chatGuid", chatGuid)
                    .putExtra("bubble", true)
                    .setType("NotificationOpen"),
                PendingIntent.FLAG_UPDATE_CURRENT);

            NotificationCompat.BubbleMetadata.Builder bubbleMetadataBuilder = new NotificationCompat.BubbleMetadata.Builder()
                .setIntent(bubbleIntent)
                .setDesiredHeight(600);

            // Set the icon to a user or group
            if (groupIcon != null) {
                bubbleMetadataBuilder.setIcon(groupIcon.toIcon());
            } else if (senderIcon != null) {
                bubbleMetadataBuilder.setIcon(senderIcon.toIcon());
            }

            notificationBuilder.setBubbleMetadata(bubbleMetadataBuilder.build());
        }

        // Send the notification
        NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);
        notificationManagerCompat.notify(existingNotificationId, notificationBuilder.build());
        result.success("");
    }
}
