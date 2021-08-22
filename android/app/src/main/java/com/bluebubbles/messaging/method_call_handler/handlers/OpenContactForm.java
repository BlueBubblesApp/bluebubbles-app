package com.bluebubbles.messaging.method_call_handler.handlers;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import androidx.core.content.FileProvider;
import android.provider.ContactsContract;
import android.provider.ContactsContract.Intents;

import java.io.File;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class OpenContactForm implements Handler {
    public static String TAG = "open-contact-form";
    private static final int REQUEST_OPEN_CONTACT_FORM = 52941;

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public OpenContactForm(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        Intent intent = new Intent(Intent.ACTION_INSERT, ContactsContract.Contacts.CONTENT_URI);
        intent.putExtra("finishActivityOnSaveCompleted", true);

        String address = (String) call.argument("address");
        String addressType = (String) call.argument("addressType");
        if (address != null) {
            String intentType = ContactsContract.Intents.Insert.PHONE;
            if (addressType != null && addressType.equals("email")) {
                intentType = ContactsContract.Intents.Insert.EMAIL;
            }

            intent.putExtra(intentType, address);
        }

        intent.addFlags(REQUEST_OPEN_CONTACT_FORM);
        context.startActivity(intent);
        result.success("");
    }
}
