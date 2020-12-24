package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.os.Build;

import androidx.annotation.RequiresApi;

import com.bluebubbles.messaging.sharing.Contact;
import com.bluebubbles.messaging.sharing.ShareShortcutManager;

import java.util.ArrayList;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class PushShareTargets implements Handler{
    public static String TAG = "push-share-targets";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;


    public PushShareTargets(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    @Override
    public void Handle() {
        ArrayList<String> names = call.argument("names");
        ArrayList<String> addresses = call.argument("addresses");
        ArrayList<byte[]> icons = call.argument("icons");

        ArrayList<Contact> contacts = new ArrayList<>();
        for(int i = 0; i < names.size(); i++) {
            contacts.add(new Contact(names.get(i), addresses.get(i), icons.get(i)));
        }
        ShareShortcutManager.publishShareTarget(context, contacts);
    }
}
