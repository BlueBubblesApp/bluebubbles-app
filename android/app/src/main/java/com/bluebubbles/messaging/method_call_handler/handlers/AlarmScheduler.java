package com.bluebubbles.messaging.method_call_handler.handlers;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;

import com.bluebubbles.messaging.services.ReplyReceiver;

import java.util.Calendar;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import static android.content.Context.ALARM_SERVICE;

public class AlarmScheduler implements Handler {
    public static String TAG = "schedule-alarm";
    public static int REQUEST_CODE = 102903;

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public AlarmScheduler(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        Long milliseconds;
        if (call.argument("milliseconds").getClass() == Long.class) {
            milliseconds = call.argument("milliseconds");
        } else if (call.argument("milliseconds").getClass() == Integer.class) {
            milliseconds = Long.valueOf(((Integer) call.argument("milliseconds")).longValue());
        } else {
            milliseconds = Long.valueOf(call.argument("milliseconds"));
        }

        Intent intent = new Intent(context, ReplyReceiver.class);
        intent.setType("alarm");
        intent.putExtra("id", (int) call.argument("id"));
        PendingIntent pendingIntent = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, 0);
        AlarmManager alarmManager = (AlarmManager)context.getSystemService(context.ALARM_SERVICE);
        alarmManager.set(AlarmManager.RTC_WAKEUP, milliseconds, pendingIntent);

    }
}
