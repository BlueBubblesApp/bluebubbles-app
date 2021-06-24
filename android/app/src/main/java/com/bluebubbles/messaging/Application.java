package com.bluebubbles.messaging;

import android.content.Context;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;

import com.baseflow.permissionhandler.PermissionHandlerPlugin;
import com.bluebubbles.messaging.workers.FCMWorker;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.ValueEventListener;
import com.tekartik.sqflite.SqflitePlugin;

import java.util.ArrayList;

import flutter.plugins.contactsservice.contactsservice.ContactsServicePlugin;
import io.flutter.app.FlutterApplication;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugins.pathprovider.PathProviderPlugin;
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin;
import io.flutter.view.FlutterCallbackInformation;
import io.flutter.view.FlutterMain;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.FlutterRunArguments;

public class Application extends FlutterApplication implements PluginRegistry.PluginRegistrantCallback {

    private PluginRegistry.PluginRegistrantCallback callback;
    PluginRegistry.PluginRegistrantCallback getCallback()  {
       return callback;
    }



    @Override
    public void onCreate() {
        super.onCreate();
        callback = this;
    }

    @Override
    public void registerWith(PluginRegistry registry) {

    }

}
