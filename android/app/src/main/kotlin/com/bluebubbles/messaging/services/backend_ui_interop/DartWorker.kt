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
import com.bluebubbles.messaging.MainActivity
import com.bluebubbles.messaging.R
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.google.gson.GsonBuilder
import com.google.gson.ToNumberPolicy
import com.google.gson.reflect.TypeToken
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.ApplicationInfoLoader
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import java.util.Timer
import kotlin.concurrent.schedule
import kotlin.coroutines.resume
import kotlinx.coroutines.guava.future
import java.io.File

// Background worker plugins — only those required for notification/sync processing
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin
import com.github.dart_lang.jni.JniPlugin
import com.johnstef.flutter_user_certificates_android.FlutterUserCertificatesAndroidPlugin
import dev.fluttercommunity.plus.device_info.DeviceInfoPlusPlugin
import dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin
import io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin
import io.flutter.plugins.pathprovider.PathProviderPlugin
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import io.objectbox.objectbox_flutter_libs.ObjectboxFlutterLibsPlugin
import net.wolverinebeach.flutter_timezone.FlutterTimezonePlugin
import org.unifiedpush.flutter.connector.Plugin as UnifiedPushConnectorPlugin

class DartWorker(context: Context, workerParams: WorkerParameters): ListenableWorker(context, workerParams) {

    companion object {
        var workerEngine: FlutterEngine? = null
        var engineReady = Mutex()
        var engineCleanup = Mutex()
    }

    override fun startWork(): ListenableFuture<Result> {
        val method = inputData.getString("method")!!
        val data = resolveWorkerPayload(inputData.getString("data")!!)
            ?: return Futures.immediateFuture(Result.failure())
        val gson = GsonBuilder()
                .setObjectToNumberStrategy(ToNumberPolicy.LONG_OR_DOUBLE)
                .create()

        val mainEngine = MainActivity.getEngine()
        if (mainEngine != null) {
            Log.d(Constants.logTag, "Using MainActivity engine to send to Dart")
        } else {
            Log.d(Constants.logTag, "Using DartWorker engine to send to Dart")
        }
        return CoroutineScope(Dispatchers.Main).future {
            engineReady.withLock {
                if (MainActivity.getEngine() == null && workerEngine == null) {
                    Log.d(Constants.logTag, "Initializing engine for worker with method $method")
                    initNewEngine()
                }
            }
            Log.d(Constants.logTag, "Sending event, '$method' to Dart")

            try {
                var engineToUse: FlutterEngine? = MainActivity.getEngine() ?: workerEngine
                if (engineToUse == null) {
                    Log.d(Constants.logTag, "Engine is null, cannot send method $method to Dart")
                    return@future Result.failure()
                }

                Log.d(Constants.logTag, "Registering engine lifecycle listener")

                engineToUse!!.addEngineLifecycleListener ( object : FlutterEngine.EngineLifecycleListener {
                    override fun onPreEngineRestart() {
                        Log.d(Constants.logTag, "Engine is restarting")
                    }

                    override fun onEngineWillDestroy() {
                        Log.d(Constants.logTag, "Engine is being destroyed")
                    }
                })

                Log.d(Constants.logTag, "Invoking method channel...")
                val callResult = withTimeoutOrNull(120_000L) {
                    suspendCancellableCoroutine { cont ->
                        MethodChannel(engineToUse!!.dartExecutor.binaryMessenger, Constants.methodChannel).invokeMethod(method, gson.fromJson(data, TypeToken.getParameterized(HashMap::class.java, String::class.java, Any::class.java).type), object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                Log.d(Constants.logTag, "Worker with method $method completed successfully")
                                if (cont.isActive) cont.resume(Result.success())
                                closeEngineIfNeeded()
                            }
    
                            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                Log.e(Constants.logTag, "Worker with method $method failed!")
                                if (cont.isActive) cont.resume(Result.failure())
                                closeEngineIfNeeded()
                            }
    
                            override fun notImplemented() {
                                Log.e(Constants.logTag, "Worker with method $method not implemented on Dart side")
                                if (cont.isActive) cont.resume(Result.failure())
                                closeEngineIfNeeded()
                            }
                        })
                    }
                }

                if (callResult == null) {
                    Log.e(Constants.logTag, "Method $method invocation timed out after 120s")
                    closeEngineIfNeeded()
                    return@future Result.failure()
                }

                Log.d(Constants.logTag, "Worker with method $method completed successfully")
                return@future Result.success()
            } catch (e: Exception) {
                Log.d(Constants.logTag, "Error sending method $method to Dart: ${e.message}")
                return@future Result.failure()
            }
        }
    }

    private fun resolveWorkerPayload(rawData: String): String? {
        if (!rawData.startsWith(DartWorkManager.DATA_FILE_MARKER)) {
            return rawData
        }

        val path = rawData.removePrefix(DartWorkManager.DATA_FILE_MARKER)
        val payloadFile = File(path)
        return try {
            val json = payloadFile.readText()
            Log.d(Constants.logTag, "Loaded ${json.length} byte worker payload from $path")
            payloadFile.delete()
            json
        } catch (e: Exception) {
            Log.e(Constants.logTag, "Failed to read worker payload file $path", e)
            payloadFile.delete()
            null
        }
    }

    /// Code idea taken from https://github.com/flutter/flutter/wiki/Experimental:-Reuse-FlutterEngine-across-screens
    private suspend fun initNewEngine() {
        Log.d(Constants.logTag, "Ensuring Flutter is initialized before creating engine")
        val flutterLoader = FlutterLoader();
        flutterLoader.startInitialization(applicationContext)
        flutterLoader.ensureInitializationComplete(applicationContext, null)

        Log.d(Constants.logTag, "Loading callback info")
        val info = ApplicationInfoLoader.load(applicationContext)
        workerEngine = FlutterEngine(applicationContext, null, FlutterJNI(), null, false)
        registerWorkerPlugins(workerEngine!!)
        val ready = withTimeoutOrNull(30_000L) {
            suspendCancellableCoroutine<Unit> { cont ->
                // set up the method channel to receive events from Dart
                MethodChannel(workerEngine!!.dartExecutor.binaryMessenger, Constants.methodChannel).setMethodCallHandler {
                    call, result -> run {
                        if (call.method == "ready") {
                            Log.d(Constants.logTag, "Dart engine is ready!")
                            if (cont.isActive) cont.resume(Unit)
                        } else {
                            MethodCallHandler().methodCallHandler(call, result, applicationContext)
                        }
                    }
                }
                val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(applicationContext.getSharedPreferences("FlutterSharedPreferences", 0).getLong("backgroundCallbackHandle", -1))
                val callback = DartExecutor.DartCallback(applicationContext.assets, info.flutterAssetsDir, callbackInfo)

                Log.d(Constants.logTag, "Executing Dart callback")
                workerEngine!!.dartExecutor.executeDartCallback(callback)
            }
        }

        if (ready == null) {
            Log.e(Constants.logTag, "Engine 'ready' handshake timed out after 30s — destroying engine")
            workerEngine?.destroy()
            workerEngine = null
            throw Exception("DartWorker engine startup timed out")
        }
    }

    private fun closeEngineIfNeeded() {
        // Delay 5 seconds so Dart has a chance to complete everything and in case new work comes in shortly after
        Timer().schedule(5000) {
            // Use runBlocking to ensure cleanup is synchronized across multiple workers
            runBlocking {
                engineCleanup.withLock {
                    // Double-check that engine still exists after acquiring lock
                    if (workerEngine == null) {
                        Log.d(Constants.logTag, "Engine already destroyed by another worker")
                        return@runBlocking
                    }

                    // Exclude this worker's own ID — WorkManager may still report it as RUNNING
                    // even after the Dart method callback has completed, which would cause the
                    // engine to never be destroyed.
                    val currentWork = WorkManager.getInstance(applicationContext).getWorkInfosByTag(Constants.dartWorkerTag).get().filter { element -> !element.state.isFinished && element.id != id }
                    Log.d(Constants.logTag, "${currentWork.size} other worker(s) still queued")
                    if (currentWork.isEmpty()) {
                        Log.d(Constants.logTag, "Closing ${Constants.dartWorkerTag} engine")
                        // This must be run on main thread
                        CoroutineScope(Dispatchers.Main).launch {
                            workerEngine?.destroy()
                            workerEngine = null
                        }
                    }
                }
            }
        }
    }

    /**
     * Registers only the plugins required for background notification and sync processing.
     * Heavy UI-only plugins (MLKit, camera, geolocator, printing, media, etc.) are excluded
     * to reduce startup overhead and avoid unnecessary initialisation in a headless context.
     */
    private fun registerWorkerPlugins(engine: FlutterEngine) {
        val plugins = engine.plugins
        // Core Flutter platform channels
        plugins.add(FlutterAndroidLifecyclePlugin())
        plugins.add(PathProviderPlugin())
        plugins.add(SharedPreferencesPlugin())
        // App information (used by FilesystemService and SettingsService init)
        plugins.add(PackageInfoPlugin())
        plugins.add(DeviceInfoPlusPlugin())
        // Database
        plugins.add(ObjectboxFlutterLibsPlugin())
        // Notifications
        plugins.add(FlutterLocalNotificationsPlugin())
        // Transport security (custom user certificates; JniPlugin is a required dependency)
        plugins.add(JniPlugin())
        plugins.add(FlutterUserCertificatesAndroidPlugin())
        // Timezone (used during message date handling)
        plugins.add(FlutterTimezonePlugin())
        // UnifiedPush
        plugins.add(UnifiedPushConnectorPlugin())
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