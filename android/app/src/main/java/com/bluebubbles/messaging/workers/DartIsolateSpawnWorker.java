package com.bluebubbles.messaging.workers;

import android.content.Context;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.work.Data;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import com.baseflow.permissionhandler.PermissionHandlerPlugin;
import com.bluebubbles.messaging.method_call_handler.MethodCallHandler;
import com.itsclicking.clickapp.fluttersocketio.FlutterSocketIoPlugin;
import com.tekartik.sqflite.SqflitePlugin;

import flutter.plugins.contactsservice.contactsservice.ContactsServicePlugin;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugins.pathprovider.PathProviderPlugin;
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin;
import io.flutter.view.FlutterCallbackInformation;
import io.flutter.view.FlutterMain;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.FlutterRunArguments;

import static com.bluebubbles.messaging.method_call_handler.handlers.InitializeBackgroundHandle.BACKGROUND_HANDLE_SHARED_PREF_KEY;
import static com.bluebubbles.messaging.method_call_handler.handlers.InitializeBackgroundHandle.BACKGROUND_SERVICE_SHARED_PREF;

public class DartIsolateSpawnWorker extends Worker {


    public DartIsolateSpawnWorker(@NonNull Context context, @NonNull WorkerParameters workerParams) {
        super(context, workerParams);
    }

    @NonNull
    @Override
    public Result doWork() {
        Data outData = new Data.Builder().build();

        return Result.success(outData);
    }


    @Override
    public void onStopped() {
        super.onStopped();
    }
}
