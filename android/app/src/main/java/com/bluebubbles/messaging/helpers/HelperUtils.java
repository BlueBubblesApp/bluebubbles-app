package com.bluebubbles.messaging.helpers;

import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.content.res.Resources;
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
import java.util.Arrays;
import java.util.ArrayList;
import java.util.HashMap;

import android.content.SharedPreferences;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import com.bluebubbles.messaging.method_call_handler.handlers.FirebaseAuth;
import com.bluebubbles.messaging.method_call_handler.handlers.GetServerUrl;

import com.bluebubbles.messaging.method_call_handler.handlers.NewMessageNotification;

public class HelperUtils {
    public static String TAG = "HelperUtils";

    public static Bitmap getCircleBitmap(Bitmap bitmap) {
        final int size = Math.round(108 * Resources.getSystem().getDisplayMetrics().density);
        final Bitmap output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888);
        final Canvas canvas = new Canvas(output);

        final int color = Color.TRANSPARENT;
        final Paint paint = new Paint();
        final int bitmapSize = Math.round(73 * Resources.getSystem().getDisplayMetrics().density);
        final int padding = (size - bitmapSize) / 2;
        final Rect _rect = new Rect(padding, padding, bitmapSize + padding, bitmapSize + padding);
        final RectF rect = new RectF(_rect);

        paint.setAntiAlias(true);
        canvas.drawARGB(0, 0, 0, 0);
        paint.setColor(color);
        canvas.drawCircle((rect.left + (rect.right - rect.left) / 2), (rect.top + (rect.bottom - rect.top) / 2), ((rect.right - rect.left) / 2), paint);

        paint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.SRC_IN));
        canvas.drawBitmap(bitmap, null, rect, null);
        bitmap.recycle();

        return output;
    }

    public static void tryCancelNotifications(Context context, Integer existingId, String existingGuid) {
        Log.d(HelperUtils.TAG, "Attempting to cancel notifications...");
        NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
        NotificationManager manager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
        ArrayList<StatusBarNotification> notifications = new ArrayList<StatusBarNotification>(Arrays.asList(manager.getActiveNotifications()));

        // We need to keep track of the count manually so that we can accurately clear the summary
        Log.d(HelperUtils.TAG, "Notification Count: " + notifications.size());

        // Only try to clear a notification if one is provided
        for (int i = 0; i < notifications.size(); i++) {
            StatusBarNotification sbNotification = notifications.get(i);
            Integer nId = sbNotification.getId();
            Boolean cancelled = false;

            // If we are passed an existing Id,
            // clear the notification with that ID
            if (existingId != null && nId.equals(existingId)) {
                Log.d(HelperUtils.TAG, "Cancelling notification by ID: " + nId.toString());
                manager.cancel(NewMessageNotification.notificationTag, nId);
                notifications.remove(i);
                cancelled = true;
            }

            // If we were passed an existing chat guid,
            // clear the notification if it's from the same chat
            if (!cancelled && existingGuid != null) {
                String chatGuid = sbNotification.getNotification().extras.getString("chatGuid");
                if (chatGuid != null && chatGuid.equals(existingGuid)) {
                    Log.d(HelperUtils.TAG, "Cancelling notification by Chat GUID: " + chatGuid);
                    manager.cancel(sbNotification.getTag(), nId);
                    notifications.remove(i);
                }
            }
        }

        Log.d(HelperUtils.TAG, "Final notification Count: " + notifications.size());

        // If there is one notification and that one notification's ID is -1, cancel it
        if (notifications.size() == 1 && notifications.get(0).getId() == -1) {
            Log.d(HelperUtils.TAG, "Cancelling summary notification");
            manager.cancel(-1);
        } else if (notifications.size() == 1 && existingId != null && existingId.equals(notifications.get(0).getId())) {
            int failedId = notifications.get(0).getId();
            Log.d(HelperUtils.TAG, "Failed to cancel notification ID: " + failedId + ". Re-cancelling...");
            manager.cancel(NewMessageNotification.notificationTag, failedId);
        }
    }

    public static void getServerUrl(Context context, String password, String identifier, MethodChannel.Result onSuccess) {
        SharedPreferences mPrefs = context.getSharedPreferences("FlutterSharedPreferences", 0);
        String storedPassword = mPrefs.getString("flutter.guidAuthKey", "");
        if (!password.equals(storedPassword)) return;
        HashMap<String, String> fcmData = new HashMap<String, String>();
        fcmData.put("project_id", mPrefs.getString("flutter.projectID", ""));
        fcmData.put("storage_bucket", mPrefs.getString("flutter.storageBucket", ""));
        fcmData.put("api_key", mPrefs.getString("flutter.apiKey", ""));
        fcmData.put("firebase_url", mPrefs.getString("flutter.firebaseURL", ""));
        fcmData.put("client_id", mPrefs.getString("flutter.clientID", ""));
        fcmData.put("application_id", mPrefs.getString("flutter.applicationID", ""));
        Map<String, String> map = new HashMap<String, String>(fcmData);
        new FirebaseAuth(context, new MethodCall("auth", map), new MethodChannel.Result() {
            @Override
            public void success(Object result) {
                new GetServerUrl(context, new MethodCall("get-server-url", null), onSuccess).Handle();
            }

            @Override
            public void error(String errorCode, String errorMessage, Object errorDetails) {
            }

            @Override
            public void notImplemented() {
            }
        }).Handle();
    }
}