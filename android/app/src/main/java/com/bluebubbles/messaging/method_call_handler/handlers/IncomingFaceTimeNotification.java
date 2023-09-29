
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

public class IncomingFaceTimeNotification implements Handler {
    public static String TAG = "incoming-facetime-notification";
    public static String GROUP_KEY = "com.bluebubbles.messaging.INCOMING_FACETIME";
    public static String notificationTag = "incoming-facetime";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public IncomingFaceTimeNotification(Context context, MethodCall call, MethodChannel.Result result) {
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

        Integer notificationId = (Integer) call.argument("notificationId");
        String title = (String) call.argument("title");
        String body = (String) call.argument("body");
        byte[] avatar = (byte[]) call.argument("avatar");
        String caller = (String) call.argument("caller");
        String callUuid = (String) call.argument("callUuid");
        Long time = (Long) call.argument("time");

        // Build a "Person" for the sender
        Person.Builder sender = new Person.Builder()
            .setName(caller)
            .setImportant(true);

        // Load the group avatar
        IconCompat senderIcon = null;
        if (avatar != null) {
            Bitmap bmp = BitmapFactory.decodeByteArray(avatar, 0, avatar.length);
            senderIcon = IconCompat.createWithAdaptiveBitmap(HelperUtils.getCircleBitmap(bmp));
        }

        // Set the icon if available
        if (senderIcon != null) {
            sender.setIcon(senderIcon);
        }

        NotificationCompat.MessagingStyle style = new NotificationCompat.MessagingStyle(sender.build());

        // Add the message to the notification
        style.addMessage(new NotificationCompat.MessagingStyle.Message(
            "Tap to answer FaceTime call",
            Long.valueOf(time).longValue(),
            sender.build()
        ));

        // Create a bundle with some extra information in it
        Bundle extras = new Bundle();
        extras.putString("callUuid", callUuid);

        // Create intent for opening the conversation in the app
        PendingIntent openIntent = PendingIntent.getActivity(
            context,
            notificationId,
            new Intent(context, MainActivity.class)
                .putExtra("callUuid", callUuid)
                .setType("NotificationOpen"),
            PendingIntent.FLAG_MUTABLE | Intent.FILL_IN_ACTION);

        // Build the actual notification
        NotificationCompat.Builder notificationBuilder = new NotificationCompat.Builder(context, channelId)
                // Set the status bar notification icon
                .setSmallIcon(R.mipmap.ic_stat_icon)
                // Add the notification to the BlueBubbles messages group
                // .setGroup(GROUP_KEY)
                // Prevent the message group notification from making sound, only let the child
                // notification make sound
                // .setGroupAlertBehavior(NotificationCompat.GROUP_ALERT_CHILDREN)
                // Let's the notification dismiss itself when it's tapped
                .setAutoCancel(true)
                // Tell android that it's a message/conversation
                .setCategory(NotificationCompat.CATEGORY_CALL)
                // Set the priority to high since it's a message they should see
                .setPriority(NotificationCompat.PRIORITY_MAX)
                // Sets the intent for when it's clicked
                .setContentIntent(openIntent)
                // Sets the style (messages/content/etc)
                .setStyle(style)
                // Add in any extra info we may want
                .addExtras(extras)
                // Set the color. This is the blue primary color
                .setColor(4888294);

        Log.d(TAG, "Creating notification for FaceTime: " + callUuid);
        NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);

        // Create the actual notification
        notificationManagerCompat.notify(notificationTag, notificationId, notificationBuilder.build());
        result.success("");
    }
}
