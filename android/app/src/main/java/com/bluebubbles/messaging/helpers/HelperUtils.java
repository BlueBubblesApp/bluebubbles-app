package com.bluebubbles.messaging.helpers;

import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.service.notification.StatusBarNotification;
import androidx.core.app.NotificationManagerCompat;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.graphics.Rect;
import android.graphics.RectF;

import android.util.Log;

import java.sql.Timestamp;
import java.util.Map;

import com.bluebubbles.messaging.method_call_handler.handlers.NewMessageNotification;

public class HelperUtils {
    public static String TAG = "HelperUtils";

    public static Object parseField(Map<String, Object> json, String field, String intendedType) {
        // Handle cases where we want to return null
        if (!json.containsKey(field) || json.get(field) == null) {
            if (intendedType.equals("boolean")) return false;  // If null, let's assume false
            return null;
        }

        String stringVal = String.valueOf(json.get(field));
        if (stringVal.equals("null")) {
            if (intendedType.equals("boolean")) return false;  // If null, let's assume false
            return null;
        }

        switch (intendedType) {
            case "integer":
                return Integer.valueOf(stringVal);
            case "long":
                return Long.valueOf(stringVal);
            case "boolean":
                return Boolean.valueOf(stringVal);
            case "timestamp":
                return new Timestamp(Long.valueOf(stringVal));
            default:
                return stringVal;
        }
    }

    public static Bitmap getCircleBitmap(Bitmap bitmap) {
        final Bitmap output = Bitmap.createBitmap(bitmap.getWidth(),
                bitmap.getHeight(), Bitmap.Config.ARGB_8888);
        final Canvas canvas = new Canvas(output);

        final int color = Color.RED;
        final Paint paint = new Paint();
        final Rect rect = new Rect(0, 0, bitmap.getWidth(), bitmap.getHeight());
        final RectF rectF = new RectF(rect);

        paint.setAntiAlias(true);
        canvas.drawARGB(0, 0, 0, 0);
        paint.setColor(color);
        canvas.drawOval(rectF, paint);

        paint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.SRC_IN));
        canvas.drawBitmap(bitmap, rect, rect, paint);

        bitmap.recycle();

        return output;
    }

    public static void tryCancelNotifications(Context context, Integer existingId, String existingGuid) {
        Log.d(HelperUtils.TAG, "Attempting to cancel notifications...");
        NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
        NotificationManager manager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
        StatusBarNotification[] notifications = manager.getActiveNotifications();

        // We need to keep track of the count manually so that we can accurately clear the summary
        Integer notificationCount = notifications.length;
        Log.d(HelperUtils.TAG, "Notification Count: " + notificationCount);

        // Only try to clear a notification if one is provided
        if (existingId != null || existingGuid != null) {
            for (StatusBarNotification sbNotification : notifications) {
                Integer nId = sbNotification.getId();
                Boolean cancelled = false;

                // If we are passed an existing Id,
                // clear the notification with that ID
                if (existingId != null && nId == existingId) {
                    manager.cancel(NewMessageNotification.notificationTag, nId);
                    cancelled = true;
                }

                // If we were passed an existing chat guid,
                // clear the notification if it's from the same chat
                if (!cancelled && existingGuid != null) {
                    String chatGuid = sbNotification.getNotification().extras.getString("chatGuid");
                    if (chatGuid != null && chatGuid.equals(existingGuid)) {
                        manager.cancel(sbNotification.getTag(), nId);
                        cancelled = true;
                    }
                }

                // If we cancelled a notification,
                // decrement the counter
                if (cancelled) {
                    notificationCount--;
                }
            }
        }
        

        // If there are no notifications... might as well cancel all, just in case.
        // If there is one notification and that one notification's ID is -1, cancel it
        if (notificationCount == 0) {
            manager.cancelAll();
        } else if (notificationCount == 1 && notifications[0].getId() == -1) {
            manager.cancel(-1);
        }
    }
}