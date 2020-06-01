package com.example.bluebubble_messages;

import android.app.RemoteInput;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import androidx.core.app.NotificationManagerCompat;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

public class ReplyReceiver extends BroadcastReceiver {


    @Override
    public void onReceive(Context context, Intent intent) {

        Bundle remoteInput = RemoteInput.getResultsFromIntent(intent);
        NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
        notificationManager.cancel(intent.getExtras().getInt("id"));
        Log.d("Notifications", "replied to notification " + remoteInput.getString("key_text_reply"));
        Intent sendMessageIntent = new Intent("myData");
        sendMessageIntent.setType("reply");
        sendMessageIntent.putExtra("text", remoteInput.getString("key_text_reply"));
        sendMessageIntent.putExtra("id", intent.getExtras().getInt("id"));

        LocalBroadcastManager.getInstance(context).sendBroadcast(sendMessageIntent);

    }
}
