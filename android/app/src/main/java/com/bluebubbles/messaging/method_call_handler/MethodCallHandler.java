package com.bluebubbles.messaging.MethodCallHandler;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Person;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.Icon;
import android.location.Location;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.MediaStore;
import android.service.notification.StatusBarNotification;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.FileProvider;

import com.bluebubbles.messaging.MainActivity;
import com.bluebubbles.messaging.R;
import com.bluebubbles.messaging.services.ReplyReceiver;
import com.bluebubbles.messaging.workers.DartWorker;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;
import com.google.firebase.iid.FirebaseInstanceId;
import com.google.firebase.iid.InstanceIdResult;

import java.io.File;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static com.bluebubbles.messaging.services.BackgroundService.app;
import static com.bluebubbles.messaging.services.BackgroundService.db;

public class MethodCallHandler {
    @SuppressLint("RestrictedApi")
    @RequiresApi(api = Build.VERSION_CODES.O)
    public static void methodCallHandler(MethodCall call, MethodChannel.Result result, Context context, ValueEventListener dbListener, FusedLocationProviderClient fusedLocationClient, DartWorker worker) {
        if (call.method.equals("auth")) {
            if (!isNetworkAvailable(context))
                result.error("no_internet", "No internet, retry in 10 seconds", "");
            if (app == null) {
                app = FirebaseApp.initializeApp(context, new FirebaseOptions.Builder()
                        .setProjectId(call.argument("project_id"))
                        .setStorageBucket(call.argument("storage_bucket"))
                        .setApiKey(call.argument("api_key"))
                        .setDatabaseUrl(call.argument("firebase_url"))
                        .setGcmSenderId(call.argument("client_id"))
                        .setApplicationId(call.argument("application_id"))
                        .build());
            }
            if (app == null) {
                result.error("could_not_initialize", "Failed to initialize, app == null", "");
            }
            FirebaseInstanceId.getInstance(app).getInstanceId()
                    .addOnCompleteListener(new OnCompleteListener<InstanceIdResult>() {
                        @Override
                        public void onComplete(@NonNull Task<InstanceIdResult> task) {
                            if (!task.isSuccessful()) {
                                Log.d("FCM", "getInstanceId failed", task.getException());
                                try {

                                    result.error("Failed to authenticate", "getInstanceId failed", task.getException());
                                } catch (IllegalStateException e) {

                                }
                            } else {

                                String token = task.getResult().getToken();
                                Log.d("FCM", "token: " + token);
                                try {
                                    result.success(token);
                                } catch (IllegalStateException e) {

                                }
                            }
                        }
                    });

            // Get the config database reference
            db = FirebaseDatabase.getInstance(app).getReference("config");
            try {
                // Remove any previous listeners
                db.removeEventListener(dbListener);
            } catch (Exception e) {
                // Don't do anything
            }

            // Re-add the listener
            db.addValueEventListener(dbListener);
        } else if (call.method.equals("close-background-isolate")) {
            if (worker != null) {
                worker.destroyHeadlessThread();
            }
            result.success("");
        } else if (call.method.equals("create-notif-channel")) {
            createNotificationChannel(call.argument("channel_name"), call.argument("channel_description"), call.argument("CHANNEL_ID"), context);
            result.success("");
        } else if (call.method.equals("new-message-notification")) {
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
                style = new NotificationCompat.MessagingStyle(androidx.core.app.Person.fromAndroidPerson(new Person.Builder().setName("You").build()));
                style.setConversationTitle(call.argument("contentTitle"));
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
            Icon icon = null;
            if (call.argument("contactIcon") != null) {
                Bitmap bmp = BitmapFactory.decodeByteArray((byte[]) call.argument("contactIcon"), 0, ((byte[]) call.argument("contactIcon")).length);
                icon = Icon.createWithBitmap(MainActivity.getCircleBitmap(bmp));
            }
            Person.Builder person = new Person.Builder().setName(call.argument("name"));
            if (icon != null) {
                person.setIcon(icon);
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
                                    (String) call.argument("group")).setType("NotificationOpen"),
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

            // Build the actual notification
            NotificationCompat.Builder builder = new NotificationCompat.Builder(context, call.argument("CHANNEL_ID"))
                    .setSmallIcon(R.mipmap.ic_stat_icon)
                    .setAllowSystemGeneratedContextualActions(true)
                    .setAutoCancel(true)
                    .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                    .setContentIntent(openIntent)
                    .addAction(dismissAction)
                    .addAction(replyAction)
                    .setStyle(style)
                    .addExtras(extras)
                    .setColor(4888294);

            // Send the notification
            NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);
            notificationManagerCompat.notify(existingNotificationId, builder.build());
            result.success("");
        } else if (call.method.equals("create-socket-issue-warning")) {
            NotificationCompat.Builder builder = new NotificationCompat.Builder(context, call.argument("CHANNEL_ID"))
                    .setSmallIcon(R.mipmap.ic_stat_icon)
                    .setContentTitle("Could not connect")
                    .setContentText("Your server may be offline")
                    .setColor(4888294)
                    .setAutoCancel(true);
            NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);
            notificationManagerCompat.notify(1000, builder.build());
            result.success("");
        } else if (call.method.equals("clear-socket-issue")) {
            NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);
            notificationManagerCompat.cancel(1000);
        } else if (call.method.equals("open_file")) {
            Intent intent = new Intent(Intent.ACTION_VIEW);
            Log.d("filesDir", "filesDir is " + context.getFilesDir().getAbsolutePath() + (String) call.argument("path"));
            Uri data = FileProvider.getUriForFile(context, "com.bluebubbles.messaging.fileprovider", new File(context.getFilesDir().getAbsolutePath() + (String) call.argument("path")));
            context.grantUriPermission(context.getPackageName(), data, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            intent.setDataAndType(data, (String) call.argument("mimeType"));
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            context.startActivity(intent);

            result.success("");
        } else if (call.method.equals("open-link")) {
            context.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(call.argument("link"))));
            result.success("");
        } else if (call.method.equals("clear-chat-notifs")) {
            NotificationManager manager = (NotificationManager) context.getSystemService(context.NOTIFICATION_SERVICE);
            for (StatusBarNotification statusBarNotification : manager.getActiveNotifications()) {
                if (statusBarNotification.getNotification().extras.getString("chatGuid") != null && statusBarNotification.getNotification().extras.getString("chatGuid").contains(Objects.requireNonNull(call.argument("chatGuid")))) {
                    NotificationManagerCompat.from(context).cancel(statusBarNotification.getId());
                } else {
                    Log.d("notification clearing", statusBarNotification.getGroupKey());
                }
            }
            result.success("");
        } else if (call.method.equals("get-last-location")) {
            // If we don't have the location client, let's get it
            if (fusedLocationClient == null)
                fusedLocationClient = LocationServices.getFusedLocationProviderClient(context);

            // Fetch the last location
            fusedLocationClient.getLastLocation()
                    .addOnSuccessListener((Activity) context, new OnSuccessListener<Location>() {
                        @Override
                        public void onSuccess(Location location) {
                            // Got last known location. In some rare situations this can be null.
                            if (location != null) {
                                // Logic to handle location object
                                Map<String, Double> latlng = new HashMap<String, Double>();
                                latlng.put("longitude", location.getLongitude());
                                latlng.put("latitude", location.getLatitude());
                                Log.d("Location", "Location retreived " + latlng.toString());
                                result.success(latlng);
                            } else {
                                Log.d("Location", "unable to retreive location");
                                result.success(null);
                            }
                        }
                    });
        } else if (call.method.equals("save-image-to-album")) {
            Intent mediaScanIntent = new Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE);
            File f = new File((String) call.argument("path"));
            Uri contentUri = Uri.fromFile(f);
            mediaScanIntent.setData(contentUri);
            context.sendBroadcast(mediaScanIntent);
            result.success("");
        } else if (call.method.equals("get-starting-intent")) {
            result.success(((MainActivity) context).getIntent().getStringExtra("chatGUID"));

        } else if (call.method.equals("initialize-background-handle")) {
            Log.d("handle", "initialize background handle: " + call.argument("handle").getClass().toString());
            Long callbackHandle;
            if (call.argument("handle").getClass() == Long.class) {
                callbackHandle = call.argument("handle");
            } else if (call.argument("handle").getClass() == Integer.class) {
                callbackHandle = Long.valueOf(((Integer) call.argument("handle")).longValue());
            } else {
                callbackHandle = Long.valueOf(call.argument("handle"));
            }

            context.getSharedPreferences(BACKGROUND_SERVICE_SHARED_PREF, Context.MODE_PRIVATE)
                    .edit()
                    .putLong(BACKGROUND_HANDLE_SHARED_PREF_KEY, callbackHandle)
                    .apply();
            result.success("");
        } else if (call.method.equals("get-server-url")) {
            // Get the server URL from Firebase
            DatabaseReference database = FirebaseDatabase.getInstance(app).getReference("config");
            ValueEventListener listener = new ValueEventListener() {
                @Override
                public void onDataChange(DataSnapshot dataSnapshot) {
                    String url = (String) dataSnapshot.child("serverUrl").getValue();
                    result.success(url);
                }

                @Override
                public void onCancelled(DatabaseError databaseError) {
                    result.success(null);
                }
            };

            database.addListenerForSingleValueEvent(listener);
        } else if (call.method.equals("share-file")) {
            HashMap<String, String> argsMap = (HashMap<String, String>) call.arguments;
            File requestFile = new File(argsMap.get("filepath"));
            Uri shareContentUri = FileProvider.getUriForFile(
                    context,
                    "com.bluebubbles.messaging.fileprovider",
                    requestFile
            );
            Intent shareIntent = new Intent(Intent.ACTION_SEND);
            shareIntent.putExtra(Intent.EXTRA_TITLE, argsMap.get("filename"));
            shareIntent.putExtra(Intent.EXTRA_STREAM, shareContentUri);
            shareIntent.setType(argsMap.get("mimeType"));
            shareIntent.setFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);


            context.startActivity(Intent.createChooser(shareIntent, argsMap.get("subject")));
        } else if (call.method.equals(("pick-image"))) {
            Intent getIntent = new Intent(Intent.ACTION_GET_CONTENT);
            getIntent.setType("image/*");

            Intent pickIntent = new Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
            pickIntent.setType("image/*");

            Intent chooserIntent = Intent.createChooser(getIntent, "Select Image");
            chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, new Intent[]{pickIntent});


            try {
                MainActivity activity = (MainActivity) context;
                activity.result = result;
                activity.startActivityForResult(chooserIntent, PICK_IMAGE);
            } catch (Exception e) {
                e.printStackTrace();
            }
        } else if (call.method.equals(("pick-video"))) {
            Intent getIntent = new Intent(Intent.ACTION_GET_CONTENT);
            getIntent.setType("video/*");

            Intent pickIntent = new Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
            pickIntent.setType("video/*");

            Intent chooserIntent = Intent.createChooser(getIntent, "Select Video");
            chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, new Intent[]{pickIntent});


            try {
                MainActivity activity = (MainActivity) context;
                activity.result = result;
                activity.startActivityForResult(chooserIntent, PICK_IMAGE);
            } catch (Exception e) {
                e.printStackTrace();
            }
        } else {
            result.notImplemented();
        }
    }
}
