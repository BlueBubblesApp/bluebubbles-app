package com.bluebubbles.messaging.services.backend_ui_interop

import android.content.Context
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.core.app.NotificationCompat
import androidx.work.ForegroundInfo
import androidx.work.ListenableWorker
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.MainActivity
import com.bluebubbles.messaging.R
import com.bluebubbles.messaging.utils.PersistentLog
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
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume
import kotlinx.coroutines.guava.future

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

        // Single lock guarding all [workerEngine] state transitions (init, use-selection,
        // and destroy) — split locks here previously allowed destroy/init races.
        var engineReady = Mutex()

        // Number of times a worker is re-enqueued after a transient failure before giving up.
        // The FCM payload lives in the work's input data, so each retry re-delivers the event.
        // With the exponential backoff configured in DartWorkManager (10s base), retries land
        // at roughly 10s/20s/40s/80s/160s — spanning ~5 minutes so they can outlast a
        // memory-pressure spike instead of all burning out inside it.
        const val MAX_RETRY_ATTEMPTS = 5

        // Cold engine boots on a thrashing device can legitimately take a long time
        const val ENGINE_READY_TIMEOUT_MS = 60_000L
    }

    /// Engine startup and method-channel failures are almost always transient (fresh headless
    /// process still initializing, engine handshake timeout, Dart handler not yet registered).
    /// Returning failure() drops the event permanently — retry with a cap instead.
    /// Every decision is persisted via PersistentLog so failures survive logcat rollover.
    private fun retryOrFail(method: String, reason: String): Result {
        return if (runAttemptCount < MAX_RETRY_ATTEMPTS) {
            PersistentLog.w(applicationContext, Constants.logTag, "Retrying worker with method $method: $reason (attempt ${runAttemptCount + 1} of $MAX_RETRY_ATTEMPTS)")
            Result.retry()
        } else {
            PersistentLog.e(applicationContext, Constants.logTag, "Worker with method $method failed after $MAX_RETRY_ATTEMPTS retries — giving up ($reason)")
            Result.failure()
        }
    }

    override fun startWork(): ListenableFuture<Result> {
        val method = inputData.getString("method")!!
        val data = inputData.getString("data")!!
        val gson = GsonBuilder()
                .setObjectToNumberStrategy(ToNumberPolicy.LONG_OR_DOUBLE)
                .create()

        return CoroutineScope(Dispatchers.Main).future {
            // Initialize AND select the engine under the same lock so a concurrent
            // cleanup can't destroy the engine between init and selection.
            val engineToUse: FlutterEngine? = try {
                engineReady.withLock {
                    // MainActivity.getEngine() can be non-null before its Dart isolate has
                    // registered a method-call handler (the engine object is attached in
                    // configureFlutterEngine, well before Dart's main() reaches
                    // MethodChannelService.init()). Invoking into it during that window
                    // always resolves notImplemented(). Only prefer it once Dart has
                    // signaled "ready" on it. Otherwise, fall back to (or spin up) the
                    // dedicated worker engine, which we know is ready before we ever use it.
                    val mainEngine = MainActivity.getEngine()
                    val mainEngineDartReady = MainActivity.isDartReady()
                    val useMainEngine = mainEngine != null && mainEngineDartReady
                    if (useMainEngine) {
                        PersistentLog.d(applicationContext, Constants.logTag, "Using MainActivity engine to send to Dart (method=$method)")
                    } else {
                        if (mainEngine != null && !mainEngineDartReady) {
                            PersistentLog.w(applicationContext, Constants.logTag, "MainActivity engine exists but Dart isn't ready yet — using DartWorker engine instead for method $method")
                        } else {
                            PersistentLog.d(applicationContext, Constants.logTag, "Using DartWorker engine to send to Dart (method=$method)")
                        }
                        if (workerEngine == null) {
                            PersistentLog.d(applicationContext, Constants.logTag, "Initializing engine for worker with method $method")
                            initNewEngine()
                        }
                    }
                    if (useMainEngine) mainEngine else workerEngine
                }
            } catch (e: Exception) {
                PersistentLog.e(applicationContext, Constants.logTag, "Engine init failed for worker with method $method: ${e.message}", e)
                return@future retryOrFail(method, "engine init failed: ${e.message}")
            }
            PersistentLog.d(applicationContext, Constants.logTag, "Sending event, '$method' to Dart")

            try {
                if (engineToUse == null) {
                    PersistentLog.d(applicationContext, Constants.logTag, "Engine is null, cannot send method $method to Dart")
                    return@future retryOrFail(method, "engine was null after init")
                }

                PersistentLog.d(applicationContext, Constants.logTag, "Invoking method channel...")
                val callResult = withTimeoutOrNull(120_000L) {
                    suspendCancellableCoroutine { cont ->
                        MethodChannel(engineToUse.dartExecutor.binaryMessenger, Constants.methodChannel).invokeMethod(method, gson.fromJson(data, TypeToken.getParameterized(HashMap::class.java, String::class.java, Any::class.java).type), object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                PersistentLog.d(applicationContext, Constants.logTag, "Worker with method $method completed successfully")
                                if (cont.isActive) cont.resume(Result.success())
                                closeEngineIfNeeded()
                            }

                            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                PersistentLog.e(applicationContext, Constants.logTag, "Worker with method $method failed! ($errorCode: $errorMessage)")
                                if (cont.isActive) cont.resume(retryOrFail(method, "Dart returned error $errorCode: $errorMessage"))
                                closeEngineIfNeeded()
                            }

                            override fun notImplemented() {
                                // notImplemented also fires when the Dart side hasn't registered its
                                // method-call handler yet (engine still starting up), so treat it as transient.
                                PersistentLog.e(applicationContext, Constants.logTag, "Worker with method $method not implemented on Dart side")
                                if (cont.isActive) cont.resume(retryOrFail(method, "method not implemented on Dart side"))
                                closeEngineIfNeeded()
                            }
                        })
                    }
                }

                if (callResult == null) {
                    PersistentLog.e(applicationContext, Constants.logTag, "Method $method invocation timed out after 120s")
                    closeEngineIfNeeded()
                    return@future retryOrFail(method, "method invocation timed out after 120s")
                }

                // callResult carries the outcome resumed by the method-channel callback
                // (success, retry, or failure) — don't collapse it to success.
                return@future callResult
            } catch (e: Exception) {
                PersistentLog.w(applicationContext, Constants.logTag, "Error sending method $method to Dart: ${e.message}", e)
                return@future retryOrFail(method, "exception sending to Dart: ${e.message}")
            }
        }
    }

    /// Code idea taken from https://github.com/flutter/flutter/wiki/Experimental:-Reuse-FlutterEngine-across-screens
    private suspend fun initNewEngine() {
        // Any failure below must not leave a half-initialized engine in [workerEngine]:
        // later workers would see it as non-null, skip init, and invoke into an engine
        // with no Dart running — hanging every subsequent event until the process dies.
        try {
            PersistentLog.d(applicationContext, Constants.logTag, "Ensuring Flutter is initialized before creating engine")
            val flutterLoader = FlutterLoader();
            flutterLoader.startInitialization(applicationContext)
            flutterLoader.ensureInitializationComplete(applicationContext, null)

            PersistentLog.d(applicationContext, Constants.logTag, "Loading callback info")
            val info = ApplicationInfoLoader.load(applicationContext)
            workerEngine = FlutterEngine(applicationContext, null, FlutterJNI(), null, false)
            registerWorkerPlugins(workerEngine!!)
            val ready = withTimeoutOrNull(ENGINE_READY_TIMEOUT_MS) {
                suspendCancellableCoroutine<Unit> { cont ->
                    // set up the method channel to receive events from Dart
                    MethodChannel(workerEngine!!.dartExecutor.binaryMessenger, Constants.methodChannel).setMethodCallHandler {
                        call, result -> run {
                            if (call.method == "ready") {
                                PersistentLog.d(applicationContext, Constants.logTag, "Dart engine is ready!")
                                if (cont.isActive) cont.resume(Unit)
                            } else {
                                MethodCallHandler().methodCallHandler(call, result, applicationContext)
                            }
                        }
                    }
                    val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(applicationContext.getSharedPreferences("FlutterSharedPreferences", 0).getLong("backgroundCallbackHandle", -1))
                    val callback = DartExecutor.DartCallback(applicationContext.assets, info.flutterAssetsDir, callbackInfo)

                    PersistentLog.d(applicationContext, Constants.logTag, "Executing Dart callback")
                    workerEngine!!.dartExecutor.executeDartCallback(callback)
                }
            }

            if (ready == null) {
                throw Exception("DartWorker engine 'ready' handshake timed out after ${ENGINE_READY_TIMEOUT_MS / 1000}s")
            }
        } catch (e: Exception) {
            PersistentLog.e(applicationContext, Constants.logTag, "Engine init failed (${e.message}) — destroying engine", e)
            workerEngine?.destroy()
            workerEngine = null
            throw e
        }
    }

    private fun closeEngineIfNeeded() {
        // Delay 5 seconds so Dart has a chance to complete everything and in case new work comes in shortly after
        CoroutineScope(Dispatchers.Main).launch {
            delay(5_000L)
            // Take the SAME lock that guards engine init/use so we can never destroy an
            // engine another worker is initializing or about to invoke into. The destroy
            // must also happen synchronously inside the lock — deferring it (the old
            // behavior) let it fire after the lock was released, racing a new init and
            // potentially destroying or orphaning a freshly created engine.
            engineReady.withLock {
                if (workerEngine == null) {
                    PersistentLog.d(applicationContext, Constants.logTag, "Engine already destroyed by another worker")
                    return@withLock
                }

                // Exclude this worker's own ID — WorkManager may still report it as RUNNING
                // even after the Dart method callback has completed, which would cause the
                // engine to never be destroyed.
                val currentWork = withContext(Dispatchers.IO) {
                    WorkManager.getInstance(applicationContext).getWorkInfosByTag(Constants.dartWorkerTag).get()
                }.filter { element -> !element.state.isFinished && element.id != id }
                PersistentLog.d(applicationContext, Constants.logTag, "${currentWork.size} other worker(s) still queued")
                if (currentWork.isEmpty()) {
                    PersistentLog.d(applicationContext, Constants.logTag, "Closing ${Constants.dartWorkerTag} engine")
                    // Already on the main thread, as engine destruction requires
                    workerEngine?.destroy()
                    workerEngine = null
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