package com.bluebubbles.messaging.method_call_handler.handlers;

import android.util.Log;
import android.annotation.SuppressLint;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
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
import android.net.Uri;
import android.service.notification.StatusBarNotification;

import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.graphics.drawable.IconCompat;
import androidx.core.app.Person;

import com.bluebubbles.messaging.MainActivity;
import com.bluebubbles.messaging.BubbleActivity;
import com.bluebubbles.messaging.R;
import com.bluebubbles.messaging.helpers.HelperUtils;
import com.bluebubbles.messaging.services.ReplyReceiver;
import com.bluebubbles.messaging.sharing.Contact;
import com.bluebubbles.messaging.sharing.ShareShortcutManager;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import java.util.Arrays;

public class NewMessageNotification implements Handler {
    public static String TAG = "new-message-notification";
    public static String GROUP_KEY = "com.bluebubbles.messaging.MESSAGE";
    public static String notificationTag = "message";

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
        String messageGuid = (String) call.argument("messageGuid");
        Long messageDate = (Long) call.argument("messageDate");
        Boolean messageIsFromMe = (Boolean) call.argument("messageIsFromMe");

        // Notification stuff
        Integer notificationId = (Integer) call.argument("notificationId");
        Integer summaryId = (Integer) call.argument("summaryId");
        String soundPath = (String) call.argument("sound");

        // Find any notifications that already exist for the chat
        NotificationManager notificationManager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
        Notification existingNotification = null;
        Integer existingNotificationId = notificationId;
        Boolean shouldReturn = false;
        for (StatusBarNotification notification : notificationManager.getActiveNotifications()) {
            String existingChatGuid = notification.getNotification().extras.getString("chatGuid");
            if (existingChatGuid == null) continue;
            if (existingChatGuid.equals(chatGuid)) {
                existingNotification = notification.getNotification();
                existingNotificationId = notification.getId();
                String existingMessageGuid = notification.getNotification().extras.getString("messageGuid");
                if (existingMessageGuid != null && existingMessageGuid.equals(messageGuid)) {
                    shouldReturn = true;
                }
                break;
            }
        }

        // if a notif with the same message guid exists, don't post a new one
        if (shouldReturn == true) {
            return;
        }

        // Build a "Person" for the sender
        Person.Builder sender = new Person.Builder()
            .setName(contactName)
            .setImportant(true);

        // Load the group avatar
        IconCompat senderIcon = null;
        if (contactAvatar != null) {
            Bitmap bmp = BitmapFactory.decodeByteArray(contactAvatar, 0, contactAvatar.length);
            senderIcon = IconCompat.createWithAdaptiveBitmap(HelperUtils.getCircleBitmap(bmp));
        }

        // Set the icon if available
        if (senderIcon != null) {
            sender.setIcon(senderIcon);
        }

        // Create a group "person" if the chat is a group
        IconCompat groupIcon = null;
        Person.Builder group = new Person.Builder();
        if (chatIsGroup) {
            group.setName(chatTitle)
                .setImportant(true);

            if (chatIcon != null) {
                Bitmap bmp = BitmapFactory.decodeByteArray(chatIcon, 0, chatIcon.length);
                groupIcon = IconCompat.createWithAdaptiveBitmap(HelperUtils.getCircleBitmap(bmp));
                group.setIcon(groupIcon);
            }
        } else {
            // If the chat isn't a group, use the sender's info
            group = sender;
        }

        // If we have an existing style, load it
        // This will load all the other messages as part of the notification as well
        NotificationCompat.MessagingStyle style;
        if (existingNotification != null) {
            Log.d(TAG, "Notification already exists, appending...");
            style = NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(existingNotification);
        } else {
            style = new NotificationCompat.MessagingStyle(group.build());
        }

        // Set whether the chat is a group conversation
        style.setGroupConversation(chatIsGroup);

        // Set the title of the conversation (in-case it may have changed)
        if (chatIsGroup) {
            style.setConversationTitle(chatTitle);
        }

        // Add the message to the notification
        style.addMessage(new NotificationCompat.MessagingStyle.Message(
            messageText,
            Long.valueOf(messageDate).longValue(),
            sender.build()
        ));

        // Create a bundle with some extra information in it
        Bundle extras = new Bundle();
        extras.putCharSequence("chatGuid", chatGuid);
        extras.putCharSequence("messageGuid", messageGuid);

        // Create intent for opening the conversation in the app
        PendingIntent openIntent = PendingIntent.getActivity(
            context,
            existingNotificationId,
            new Intent(context, MainActivity.class)
                .putExtra("id", existingNotificationId)
                .putExtra("chatGuid", chatGuid)
                .putExtra("messageGuid", messageGuid)
                .putExtra("bubble", "false")
                .setType("NotificationOpen"),
            PendingIntent.FLAG_MUTABLE | Intent.FILL_IN_ACTION);

        // Create intent for opening the app when the summary is pressed
        PendingIntent openSummaryIntent = PendingIntent.getActivity(
                context,
                -1,
                new Intent(context, MainActivity.class)
                        .putExtra("id", -1)
                        .putExtra("chatGuid", "-1")
                        .putExtra("bubble", "false")
                        .setType("NotificationOpen"),
                PendingIntent.FLAG_MUTABLE | Intent.FILL_IN_ACTION);

        // Create intent for swiping away the notification
        PendingIntent swipeAwayIntent = PendingIntent.getBroadcast(
                context,
                existingNotificationId,
                new Intent(context, ReplyReceiver.class)
                        .putExtra("id", existingNotificationId)
                        .putExtra("chatGuid", chatGuid)
                        .putExtra("messageGuid", messageGuid)
                        .putExtra("bubble", "false")
                        .setType("swipeAway"),
                PendingIntent.FLAG_MUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);

        // Create intent for dismissing the notification (mark as read)
        PendingIntent dismissIntent = PendingIntent.getBroadcast(
            context,
            existingNotificationId,
            new Intent(context, ReplyReceiver.class)
                .putExtra("id", existingNotificationId)
                .putExtra("chatGuid", chatGuid)
                .putExtra("messageGuid", messageGuid)
                .putExtra("bubble", "false")
                .setType("markAsRead"),
                PendingIntent.FLAG_MUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);

        // Create intent for quick reply
        Intent intent = new Intent(context, ReplyReceiver.class)
            .putExtra("id", existingNotificationId)
            .putExtra("chatGuid", chatGuid)
            .putExtra("messageGuid", messageGuid)
            .putExtra("channelName", channelName)
            .putExtra("channelID", channelId)
            .putExtra("bubble", "false")
            .setType("reply");

        // Create the dismiss action (mark as read)
        NotificationCompat.Action dismissAction = new NotificationCompat.Action.Builder(0, "Mark As Read", dismissIntent)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_MARK_AS_READ)
            .setShowsUserInterface(false)
            .build();

        PendingIntent replyIntent = PendingIntent.getBroadcast(context, existingNotificationId, intent, PendingIntent.FLAG_MUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        NotificationCompat.Action.Builder replyActionBuilder = null;

        // SEMANTIC_ACTION_REPLY isn't supported until API level 28 so we need to programatically
        // apply it
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.O) {
            replyActionBuilder = new NotificationCompat.Action.Builder(0, "Reply", replyIntent)
                    .setShowsUserInterface(false)
                    .extend(new NotificationCompat.Action.WearableExtender().setHintDisplayActionInline(true));
        } else {
            replyActionBuilder = new NotificationCompat.Action.Builder(0, "Reply", replyIntent)
                    .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
                    .setShowsUserInterface(false)
                    .extend(new NotificationCompat.Action.WearableExtender().setHintDisplayActionInline(true));
        }

        // Generate contextual interactive buttons
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            replyActionBuilder.setAllowGeneratedReplies(true);
        }

        // Add remote input replier
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            androidx.core.app.RemoteInput replyInput = new androidx.core.app.RemoteInput.Builder("key_text_reply").setLabel("Reply").build();
            replyActionBuilder.addRemoteInput(replyInput);
        }

        // Build the actual notification
        NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(context, channelId)
                // Set the status bar notification icon
                .setSmallIcon(R.mipmap.ic_stat_icon)
                // Add the notification to the BlueBubbles messages group
                .setGroup(GROUP_KEY)
                // Prevent the message group notification from making sound, only let the child
                // notification make sound
                .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)
                // Let's the notification dismiss itself when it's tapped
                .setAutoCancel(true)
                // Tell android that it's a message/conversation
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                // Set the priority to high since it's a message they should see
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                // Sets the intent for when it's clicked
                .setContentIntent(openIntent)
                // Sets the intent for when it is swiped away
                .setDeleteIntent(swipeAwayIntent)
                // Adds the mark as read action
                .addAction(dismissAction)
                // Adds the reply action
                .addAction(replyActionBuilder.build())
                // Sets the style (messages/content/etc)
                .setStyle(style)
                // Set the shortcut ID to the chat GUID since it's already unique
                .setShortcutId(chatGuid)
                // Add in any extra info we may want
                .addExtras(extras)
                // Set the color. This is the blue primary color
                .setColor(4888294);

        // Set the sound of the notification (Android 7 and below)
        if (soundPath != "default") {
            int soundResourceId = context.getResources().getIdentifier(soundPath, "raw", context.getPackageName());
            notificationBuilder.setSound(Uri.parse("android.resource://" + context.getPackageName() + "/" + soundResourceId));
        }

        // Disable the alert if it's from you
        notificationBuilder.setOnlyAlertOnce(messageIsFromMe);

        // Generate contextual interactive buttons
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            notificationBuilder.setAllowSystemGeneratedContextualActions(true);
        }

//        if (Build.VERSION.SDK_INT >= 30) {
//            PendingIntent bubbleIntent = PendingIntent.getActivity(
//                    context,
//                    existingNotificationId,
//                    new Intent(context, BubbleActivity.class)
//                            .putExtra("id", existingNotificationId)
//                            .putExtra("chatGuid", chatGuid)
//                            .putExtra("bubble", "true")
//                            .setType("NotificationOpen"),
//                    PendingIntent.FLAG_MUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
//
//            NotificationCompat.BubbleMetadata.Builder bubbleMetadataBuilder = new NotificationCompat.BubbleMetadata.Builder()
//                    .setIntent(bubbleIntent)
//                    .setDesiredHeight(600)
//                    .setAutoExpandBubble(false)
//                    .setSuppressNotification(true);
//
//            // Set the icon to a user or group or fallback to the BB icon
//            if (groupIcon != null) {
//                bubbleMetadataBuilder.setIcon(groupIcon);
//            } else if (senderIcon != null) {
//                bubbleMetadataBuilder.setIcon(senderIcon);
//            } else {
//                bubbleMetadataBuilder.setIcon(IconCompat.createWithResource(context, R.mipmap.ic_stat_icon));
//            }
//
//            notificationBuilder.setBubbleMetadata(bubbleMetadataBuilder.build());
//        }

        Log.d(TAG, "Creating notification for chat: " + chatGuid + " - With ID: " + existingNotificationId);
        NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);

        // Create/Update the summary notification
        NotificationCompat.Builder summaryNotificationBuilder = new NotificationCompat.Builder(context, channelId)
                // Set the status bar notification icon
                .setSmallIcon(R.mipmap.ic_stat_icon)
                // Add the notification to the BlueBubbles messages group
                .setGroup(GROUP_KEY)
                // Tell Android this is a summary notification so everything should be grouped inside it
                .setGroupSummary(true)
                // Prevent the message group notification from making sound, only let the child
                // notification make sound
                .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)
                // Let's the notification dismiss itself when it's tapped
                .setAutoCancel(true)
                // Set the priority to high since it's a notification they should see
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                // Sets the intent for when it's clicked
                .setContentIntent(openSummaryIntent)
                // Set the color. This is the blue primary color
                .setColor(4888294);

        // Create the actual notification
        notificationManagerCompat.notify(notificationTag, existingNotificationId, notificationBuilder.build());

        notificationManagerCompat.notify(-1, summaryNotificationBuilder.build());
        
        result.success("");
    }
}
