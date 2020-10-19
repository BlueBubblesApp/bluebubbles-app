package com.bluebubbles.messaging.method_call_handler;

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
import com.bluebubbles.messaging.method_call_handler.handlers.ClearChatNotifs;
import com.bluebubbles.messaging.method_call_handler.handlers.ClearSocketIssue;
import com.bluebubbles.messaging.method_call_handler.handlers.CreateNotificationChannel;
import com.bluebubbles.messaging.method_call_handler.handlers.FirebaseAuth;
import com.bluebubbles.messaging.method_call_handler.handlers.GetLastLocation;
import com.bluebubbles.messaging.method_call_handler.handlers.GetServerUrl;
import com.bluebubbles.messaging.method_call_handler.handlers.InitializeBackgroundHandle;
import com.bluebubbles.messaging.method_call_handler.handlers.NewMessageNotification;
import com.bluebubbles.messaging.method_call_handler.handlers.OpenFile;
import com.bluebubbles.messaging.method_call_handler.handlers.OpenLink;
import com.bluebubbles.messaging.method_call_handler.handlers.PickImage;
import com.bluebubbles.messaging.method_call_handler.handlers.PickVideo;
import com.bluebubbles.messaging.method_call_handler.handlers.SaveToFile;
import com.bluebubbles.messaging.method_call_handler.handlers.ShareFile;
import com.bluebubbles.messaging.method_call_handler.handlers.SocketIssueWarning;
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


public class MethodCallHandler {
    @SuppressLint("RestrictedApi")
    @RequiresApi(api = Build.VERSION_CODES.O)
    public static void methodCallHandler(MethodCall call, MethodChannel.Result result, Context context, FusedLocationProviderClient fusedLocationClient, DartWorker worker) {
        if (call.method.equals(FirebaseAuth.TAG)) {
            new FirebaseAuth(context, call, result).Handle();
        } else if (call.method.equals("close-background-isolate")) {
            if (worker != null) {
                worker.destroyHeadlessThread();
            }
            result.success("");
        } else if (call.method.equals(CreateNotificationChannel.TAG)) {
            new CreateNotificationChannel(context, call, result).Handle();
        } else if (call.method.equals(NewMessageNotification.TAG)) {
            new NewMessageNotification(context, call, result).Handle();
        } else if (call.method.equals(SocketIssueWarning.TAG)) {
            new SocketIssueWarning(context, call, result).Handle();
        } else if (call.method.equals(ClearSocketIssue.TAG)) {
            new ClearSocketIssue(context, call, result).Handle();
        } else if (call.method.equals(OpenFile.TAG)) {
            new OpenFile(context, call, result).Handle();
        } else if (call.method.equals(OpenLink.TAG)) {
            new OpenLink(context, call, result).Handle();
        } else if (call.method.equals(ClearChatNotifs.TAG)) {
            new ClearChatNotifs(context, call, result).Handle();
        } else if (call.method.equals(GetLastLocation.TAG)) {
            new GetLastLocation(context, call, result, fusedLocationClient).Handle();
        } else if (call.method.equals(SaveToFile.TAG)) {
            new SaveToFile(context, call, result).Handle();
        } else if (call.method.equals("get-starting-intent")) {
            result.success(((MainActivity) context).getIntent().getStringExtra("chatGUID"));
        } else if (call.method.equals(InitializeBackgroundHandle.TAG)) {
            new InitializeBackgroundHandle(context, call, result).Handle();
        } else if (call.method.equals(GetServerUrl.TAG)) {
            new GetServerUrl(context, call, result).Handle();
        } else if (call.method.equals(ShareFile.TAG)) {
            new ShareFile(context, call, result).Handle();
        } else if (call.method.equals(PickImage.TAG)) {
            new PickImage(context, call, result).Handle();
        } else if (call.method.equals(PickVideo.TAG)) {
            new PickVideo(context, call, result).Handle();
        } else {
            result.notImplemented();
        }
    }
}
