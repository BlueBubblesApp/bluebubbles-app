package com.bluebubbles.messaging.services.backend_ui_interop

import android.content.Context
import android.util.Log
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.core.app.NotificationCompat
import androidx.work.ForegroundInfo
import androidx.work.ListenableWorker
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.MainActivity.Companion.engine
import com.bluebubbles.messaging.R
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.google.gson.GsonBuilder
import com.google.gson.ToNumberPolicy
import com.google.gson.reflect.TypeToken
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.ApplicationInfoLoader
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import io.flutter.view.FlutterMain
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.Timer
import kotlin.concurrent.schedule
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine
import kotlinx.coroutines.guava.future

class DartWorker(context: Context, workerParams: WorkerParameters): ListenableWorker(context, workerParams) {

    companion object {
        var workerEngine: FlutterEngine? = null
        var engineReady = Mutex()
    }

    override fun startWork(): ListenableFuture<Result> {
        val method = inputData.getString("method")!!
        val data = inputData.getString("data")!!
        val gson = GsonBuilder()
                .setObjectToNumberStrategy(ToNumberPolicy.LONG_OR_DOUBLE)
                .create()

        if (engine != null) {
            Log.d(Constants.logTag, "Using MainActivity engine to send to Dart")
        } else {
            Log.d(Constants.logTag, "Using DartWorker engine to send to Dart")
        }
        return CoroutineScope(Dispatchers.Main).future {
            engineReady.withLock {
                if (engine == null && workerEngine == null) {
                    Log.d(Constants.logTag, "Initializing engine for worker with method $method")
                    initNewEngine()
                }
            }
            Log.d(Constants.logTag, "Sending method $method to Dart")
            suspendCoroutine { cont ->
                MethodChannel((engine ?: workerEngine)!!.dartExecutor.binaryMessenger, Constants.methodChannel).invokeMethod(method, gson.fromJson(data, TypeToken.getParameterized(HashMap::class.java, String::class.java, Any::class.java).type), object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        Log.d(Constants.logTag, "Worker with method $method completed successfully")
                        cont.resume(Result.success())
                        closeEngineIfNeeded()
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.e(Constants.logTag, "Worker with method $method failed!")
                        cont.resume(Result.failure())
                        closeEngineIfNeeded()
                    }

                    override fun notImplemented() { }
                })
            }
        }
    }

    /// Code idea taken from https://github.com/flutter/flutter/wiki/Experimental:-Reuse-FlutterEngine-across-screens
    private suspend fun initNewEngine() {
        Log.d(Constants.logTag, "Ensuring Flutter is initialized before creating engine")
        // We use the deprecated class here anyways, the new one doesn't work correctly using the same code
        FlutterMain.startInitialization(applicationContext)
        FlutterMain.ensureInitializationComplete(applicationContext, null)

        Log.d(Constants.logTag, "Loading callback info")
        val info = ApplicationInfoLoader.load(applicationContext)
        workerEngine = FlutterEngine(applicationContext)
        suspendCoroutine { cont ->
            // set up the method channel to receive events from Dart
            MethodChannel(workerEngine!!.dartExecutor.binaryMessenger, Constants.methodChannel).setMethodCallHandler {
                call, result -> run {
                    if (call.method == "ready") {
                        cont.resume(Unit)
                    } else {
                        MethodCallHandler().methodCallHandler(call, result, applicationContext)
                    }
                }
            }
            val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(applicationContext.getSharedPreferences("FlutterSharedPreferences", 0).getLong("flutter.backgroundCallbackHandle", -1))
            val callback = DartExecutor.DartCallback(applicationContext.assets, info.flutterAssetsDir, callbackInfo)

            Log.d(Constants.logTag, "Executing Dart callback")
            workerEngine!!.dartExecutor.executeDartCallback(callback)
        }
    }

    private fun closeEngineIfNeeded() {
        // Delay 5 seconds so Dart has a chance to complete everything and in case new work comes in shortly after
        Timer().schedule(5000) {
            val currentWork = WorkManager.getInstance(applicationContext).getWorkInfosByTag(Constants.dartWorkerTag).get().filter { element -> !element.state.isFinished }
            Log.d(Constants.logTag, "${currentWork.size} worker(s) still queued")
            if (currentWork.isEmpty() && workerEngine != null) {
                Log.d(Constants.logTag, "Closing ${Constants.dartWorkerTag} engine")
                // This must be run on main thread
                CoroutineScope(Dispatchers.Main).launch {
                    workerEngine?.destroy()
                }
                workerEngine = null
            }
        }
    }

    // Dumb thing that appears to be necessary for Android 11 and under (see https://stackoverflow.com/questions/69684656/upgrading-to-workmanager-2-7-0-how-to-implement-getforegroundinfoasync-for-rxwo)
    override fun getForegroundInfoAsync(): ListenableFuture<ForegroundInfo> {
        val notification = NotificationCompat.Builder(applicationContext, "com.bluebubbles.foreground_service")
            .setSmallIcon(R.mipmap.ic_stat_icon)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentTitle("BlueBubbles DartWorker")
            .setContentText("BlueBubbles is performing short work in the background")
            .setColor(4888294)
            .build()
        return Futures.immediateFuture(ForegroundInfo(Constants.dartWorkerNotificationId, notification))
    }
}