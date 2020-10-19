package com.bluebubbles.messaging.workers;

import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.work.Data;
import androidx.work.ExistingWorkPolicy;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import com.baseflow.permissionhandler.PermissionHandlerPlugin;
import com.bluebubbles.messaging.helpers.NotifyRunnable;
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

import static com.bluebubbles.messaging.MainActivity.engine;
import static com.bluebubbles.messaging.method_call_handler.handlers.InitializeBackgroundHandle.BACKGROUND_HANDLE_SHARED_PREF_KEY;
import static com.bluebubbles.messaging.method_call_handler.handlers.InitializeBackgroundHandle.BACKGROUND_SERVICE_SHARED_PREF;

public class FCMWorker extends Worker implements DartWorker {

    private FlutterNativeView backgroundView;
    private MethodChannel backgroundChannel;

    public static final String TAG = "FCMWorker";

    public FCMWorker(@NonNull Context appContext, @NonNull WorkerParameters workerParams) {
        super(appContext, workerParams);
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    @NonNull
    @Override
    public Result doWork() {
        String type = getInputData().getString("type");
        Log.d("work", "Do work");
        if (type.equals("new-message") || type.equals("updated-message")) {

            getBackgroundChannel();
            invokeMethod();
            // We don't want to finish this worker until we know the backgroundChannel is finished
            // The backgroundChannel is manually closed through dart code
            while (backgroundChannel != null && !isStopped()) {
            }
            return Result.success();
        } else {

            return Result.failure();
        }
    }

    @Override
    public void onStopped() {
        // When this worker gets cancelled, we need to clean up
        destroyHeadlessThread();
        super.onStopped();
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    private void initHeadlessThread() {
        if (backgroundView == null) {
            FlutterMain.ensureInitializationComplete(getApplicationContext(), null);

            Long callbackHandle = getApplicationContext().getSharedPreferences(BACKGROUND_SERVICE_SHARED_PREF, Context.MODE_PRIVATE).getLong(BACKGROUND_HANDLE_SHARED_PREF_KEY, 0);
            FlutterCallbackInformation callbackInformation = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle);

            backgroundView = new FlutterNativeView(getApplicationContext(), true);
            PluginRegistry registry = backgroundView.getPluginRegistry();
            SqflitePlugin.registerWith(registry.registrarFor("com.tekartik.sqflite.SqflitePlugin"));
            PathProviderPlugin.registerWith(registry.registrarFor("plugins.flutter.io/path_provider"));
            FlutterSocketIoPlugin.registerWith(registry.registrarFor("flutter_socket_io"));
            PermissionHandlerPlugin.registerWith(registry.registrarFor("flutter.baseflow.com/permissions/methods"));
            ContactsServicePlugin.registerWith(registry.registrarFor("github.com/clovisnicolas/flutter_contacts"));
            SharedPreferencesPlugin.registerWith(registry.registrarFor("plugins.flutter.io/shared_preferences"));


            FlutterRunArguments args = new FlutterRunArguments();
            args.bundlePath = FlutterMain.findAppBundlePath();
            args.entrypoint = callbackInformation.callbackName;
            args.libraryPath = callbackInformation.callbackLibraryPath;

            backgroundView.runFromBundle(args);
            backgroundChannel = new MethodChannel(backgroundView, "background_isolate");

            backgroundChannel.setMethodCallHandler((call, result) -> MethodCallHandler.methodCallHandler(call, result, getApplicationContext(), null, this));
        }
    }


    @Override
    public void destroyHeadlessThread() {
        if (backgroundView == null) return;
        new Handler(Looper.getMainLooper()).post(() -> {
            if (backgroundView != null) {
                try {
                    backgroundView.destroy();
                    backgroundView = null;
                    backgroundChannel = null;
                    Log.d("Destroy", "Destroyed isolate");
                } catch (Exception e) {

                }
            }
        });
    }


    private void invokeMethod() {
        Handler handler = new Handler(Looper.getMainLooper());
        synchronized (handler) {
            NotifyRunnable runnable = new NotifyRunnable(handler, () -> backgroundChannel.invokeMethod(getInputData().getString("type"), getInputData().getString("data")));
            handler.post(runnable);
            while (!runnable.isFinished()) {
                try {
                    handler.wait();
                } catch (InterruptedException is) {
                    // ignore
                }
            }
        }
    }


    @RequiresApi(api = Build.VERSION_CODES.O)
    public MethodChannel getBackgroundChannel() {
        if (backgroundChannel == null) {

            Handler handler = new Handler(Looper.getMainLooper());
            synchronized (handler) {
                NotifyRunnable runnable = new NotifyRunnable(handler, () -> initHeadlessThread());
                handler.post(runnable);
                while (!runnable.isFinished()) {
                    try {
                        handler.wait();
                    } catch (InterruptedException is) {
                        // ignore
                    }
                }
            }
        }
        return backgroundChannel;
    }

    public static void createWorker(Context context, String type, String data) {
        if(engine != null) return;
        OneTimeWorkRequest fcmwork = new OneTimeWorkRequest.Builder(FCMWorker.class)
                .setInputData(
                        new Data.Builder()
                                .putString("type", type)
                                .putString("data", data)
                                .build()
                )
                .addTag(FCMWorker.TAG)
                .build();
        WorkManager.getInstance(context).enqueueUniqueWork(FCMWorker.TAG, ExistingWorkPolicy.APPEND_OR_REPLACE, fcmwork);
    }
}
