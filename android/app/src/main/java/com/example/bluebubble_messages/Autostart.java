package com.example.bluebubble_messages;


import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

public class autostart extends BroadcastReceiver
{
    protected ServiceConnection mServerConn = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder binder) {
            backgroundService = ((BackgroundService.LocalBinder) binder).getService();
            backgroundService.setAlive(true);
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            backgroundService = null;
        }
    };
    public void onReceive(Context context, Intent arg1)
    {
        Intent intent = new Intent(context,BackgroundService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
        context.bindService(new Intent(context, BackgroundService.class), mServerConn, Context.BIND_AUTO_CREATE);
        Log.i("Autostart", "started");
    }
}

