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

public class ViewContactForm implements Handler {
    public static String TAG = "view-contact-form";
    private static final int REQUEST_OPEN_EXISTING_CONTACT = 52942;

    private Context context;
    private MethodCall call;
    private MethodChannel.Result result;

    public ViewContactForm(Context context, MethodCall call,  MethodChannel.Result result) {
        this.context = context;
        this.call = call;
        this.result = result;
    }

    @Override
    public void Handle() {
        String contactId = (String) call.argument("id");
        Uri uri = Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_URI, contactId);
        Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(uri, ContactsContract.Contacts.CONTENT_ITEM_TYPE);
        intent.putExtra("finishActivityOnSaveCompleted", true);

        intent.addFlags(REQUEST_OPEN_EXISTING_CONTACT);
        context.startActivity(intent);
        result.success("");
    }
}
