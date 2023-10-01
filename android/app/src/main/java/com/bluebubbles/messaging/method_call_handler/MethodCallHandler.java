package com.bluebubbles.messaging.method_call_handler;

import android.annotation.SuppressLint;
import android.app.AlarmManager;
import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.pm.PackageManager;
import android.content.Context;
import android.net.Uri;
import android.os.Build;
import android.content.Intent;
import android.provider.Settings;

import androidx.annotation.RequiresApi;

import com.bluebubbles.messaging.MainActivity;
import com.bluebubbles.messaging.helpers.FileDirectory;
import com.bluebubbles.messaging.method_call_handler.handlers.ClearChatNotifs;
import com.bluebubbles.messaging.method_call_handler.handlers.CreateNotificationChannel;
import com.bluebubbles.messaging.method_call_handler.handlers.DownloadHandler;
import com.bluebubbles.messaging.method_call_handler.handlers.FirebaseAuth;
import com.bluebubbles.messaging.method_call_handler.handlers.GetServerUrl;
import com.bluebubbles.messaging.method_call_handler.handlers.InitializeBackgroundHandle;
import com.bluebubbles.messaging.method_call_handler.handlers.MediaSessionListener;
import com.bluebubbles.messaging.method_call_handler.handlers.IncomingFaceTimeNotification;
import com.bluebubbles.messaging.method_call_handler.handlers.NewMessageNotification;
import com.bluebubbles.messaging.method_call_handler.handlers.OpenLink;
import com.bluebubbles.messaging.method_call_handler.handlers.PushShareTargets;
import com.bluebubbles.messaging.method_call_handler.handlers.SetNextRestart;
import com.bluebubbles.messaging.method_call_handler.handlers.OpenContactForm;
import com.bluebubbles.messaging.method_call_handler.handlers.ViewContactForm;
import com.bluebubbles.messaging.workers.DartWorker;
import static com.bluebubbles.messaging.MainActivity.engine;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import java.util.HashMap;


public class MethodCallHandler {
    @SuppressLint("RestrictedApi")
    @RequiresApi(api = Build.VERSION_CODES.P)
    public static void methodCallHandler(MethodCall call, MethodChannel.Result result, Context context, DartWorker worker) {
        if (call.method.equals(FirebaseAuth.TAG)) {
            new FirebaseAuth(context, call, result).Handle();
        } else if (call.method.equals("close-background-isolate")) {
            if (worker != null) {
                worker.destroyHeadlessThread();
            }
            result.success("");
        } else if (call.method.equals(CreateNotificationChannel.TAG)) {
            new CreateNotificationChannel(context, call, result).Handle();
        } else if (call.method.equals(IncomingFaceTimeNotification.TAG)) {
            new IncomingFaceTimeNotification(context, call, result).Handle();
        } else if (call.method.equals(NewMessageNotification.TAG)) {
            new NewMessageNotification(context, call, result).Handle();
        } else if (call.method.equals(OpenLink.TAG)) {
            new OpenLink(context, call, result).Handle();
        } else if (call.method.equals(ClearChatNotifs.TAG)) {
            new ClearChatNotifs(context, call, result).Handle();
        } else if(call.method.equals(PushShareTargets.TAG)) {
            new PushShareTargets(context, call, result).Handle();
        } else if (call.method.equals(InitializeBackgroundHandle.TAG)) {
            new InitializeBackgroundHandle(context, call, result).Handle();
        } else if (call.method.equals(GetServerUrl.TAG)) {
            new GetServerUrl(context, call, result).Handle();
        } else if (call.method.equals(SetNextRestart.TAG)) {
            new SetNextRestart(context, call, result).Handle();
        } else if (call.method.equals(DownloadHandler.TAG)) {
            new DownloadHandler(context, call, result).Handle();
        } else if (call.method.equals(OpenContactForm.TAG)) {
            new OpenContactForm(context, call, result).Handle();
        } else if (call.method.equals(ViewContactForm.TAG)) {
            new ViewContactForm(context, call, result).Handle();
        } else if (call.method.equals("start-notif-listener")) {
            if (Settings.Secure.getString(context.getContentResolver(),"enabled_notification_listeners").contains(context.getPackageName()) && engine != null) {
                new MediaSessionListener(context, call, result).Handle();
            } else {
                result.error("could_not_initialize", "Failed to initialize, permission not granted", "");
            }
        } else if (call.method.equals("request-notif-permission")) {
            if (Settings.Secure.getString(context.getContentResolver(),"enabled_notification_listeners").contains(context.getPackageName())) {
                result.success("");
            } else {
                MainActivity activity = (MainActivity) context;
                activity.result = result;
                Intent intent = new Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS");
                activity.startActivityForResult(intent, MainActivity.NOTIFICATION_SETTINGS);
            }
        } else if (call.method.equals("get-content-path")) {
            final String path = FileDirectory.INSTANCE.getAbsolutePath(context, Uri.parse((String) call.argument("uri")));
            result.success(path);
        } else if (call.method.equals("open-convo-notif-settings")) {
            NotificationChannel channel = new NotificationChannel(call.argument("id"), call.argument("displayName"), NotificationManager.IMPORTANCE_MAX);
            channel.setConversationId(call.argument("parentId"), call.argument("id"));
            channel.enableLights(true);
            NotificationManager notificationManager = context.getSystemService(NotificationManager.class);
            notificationManager.createNotificationChannel(channel);
            Intent intent = new Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS);
            intent.putExtra(Settings.EXTRA_APP_PACKAGE, context.getPackageName());
            intent.putExtra(Settings.EXTRA_CHANNEL_ID, channel.getId());
            intent.putExtra(Settings.EXTRA_CONVERSATION_ID, channel.getConversationId());
            context.startActivity(intent);
            result.success("");
        } else if (call.method.equals("check-chromeos")) {
            PackageManager pm = context.getPackageManager();
            Boolean chromeOS = pm.hasSystemFeature("org.chromium.arc") || pm.hasSystemFeature("org.chromium.arc.device_management");
            result.success(chromeOS);
        } else if (call.method.equals("open-calendar")) {
            Intent intent = new Intent(Intent.ACTION_EDIT);
            intent.setType("vnd.android.cursor.item/event");
            intent.putExtra("beginTime", (long) call.argument("date"));
            context.startActivity(intent);
        } else if (call.method.equals("google-duo")) {
            Intent intent = new Intent();
            intent.setPackage("com.google.android.apps.tachyon");
            intent.setAction("com.google.android.apps.tachyon.action.CALL");
            intent.setData(Uri.parse("tel:" + (String) call.argument("number")));
            context.startActivity(intent);
        } else {
            result.notImplemented();
        }
    }
}
