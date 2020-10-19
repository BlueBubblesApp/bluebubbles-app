package com.bluebubbles.messaging;

import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.FlutterNativeView;

public class FCMWorker extends Worker {


    private static final String TAG = "FCMWorker";

    public FCMWorker(@NonNull Context appContext, @NonNull WorkerParameters workerParams) {
        super(appContext, workerParams);
    }

    @RequiresApi(api = Build.VERSION_CODES.O)
    @NonNull
    @Override
    public Result doWork() {
        Application application = (Application) getApplicationContext();
        MethodChannel backgroundChannel = application.getBackgroundChannel();

        new Handler().postDelayed(() -> {
           Log.d("FCMWorker", "There are " + application.tasks + " tasks") ;
        }, 500);
        return Result.success();
    }
}
