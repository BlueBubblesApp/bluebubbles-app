package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.DatabaseReference;

import static com.bluebubbles.messaging.method_call_handler.handlers.FirebaseAuth.app;

public class SetNextRestart implements Handler {
    public static String TAG = "set-next-restart";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public SetNextRestart(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        Long newValue = call.argument("value");

        Log.d("(SetNextRestart Handler)", "Setting new value: " + newValue.toString());
        DatabaseReference database = FirebaseDatabase.getInstance(app).getReference("config");
        database.child("nextRestart").setValue(newValue);

        result.success("");
    }
}