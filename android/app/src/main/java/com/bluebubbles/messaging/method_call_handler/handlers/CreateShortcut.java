package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.graphics.drawable.Icon;

import androidx.core.app.Person;
import androidx.core.content.pm.ShortcutInfoCompat;
import androidx.core.content.pm.ShortcutManagerCompat;
import androidx.core.graphics.drawable.IconCompat;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class CreateShortcut implements Handler {

    public static String TAG = "create-shortcut";

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public CreateShortcut(Context context, MethodCall call, MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
//        Icon contactIcon = Icon.createWithData();
//        IconCompat icon = IconCompat.createFromIcon();
//        Person.Builder person = new Person.Builder()
//                .setName(call.argument("name"))
//                .setIcon(call.argument());
//
//        ShortcutManagerCompat.pushDynamicShortcut(context, new ShortcutInfoCompat.Builder(context, (String) call.argument("id") )
//                .setPerson(person.build())
//                .setLongLived(true)
//                .build());
    }
}
