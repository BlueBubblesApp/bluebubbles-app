package com.bluebubbles.messaging

import android.content.ComponentCallbacks2
import android.content.Context
import android.content.res.Configuration
import android.os.Bundle
import com.bluebubbles.messaging.services.backend_ui_interop.MethodCallHandler
import com.bluebubbles.messaging.utils.PersistentLog
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class BubbleActivity : FlutterFragmentActivity() {
    companion object {
        private const val DART_ENTRYPOINT = "bubble"

        private const val KEPT_ENGINE_ID = "bubble"

        /// Destroy the kept engine when Android asks the process for memory back, so the next bubble starts cold.
        /// Set to false to keep it for the life of the process instead.
        private const val DESTROY_KEPT_ENGINE_ON_TRIM = true

        private var keptEngineHost: BubbleActivity? = null

        /// The activity drawing on the kept engine, which is not always [keptEngineHost]: a closing bubble stops
        /// hosting in onPause but stays attached until onDestroy. The engine must not be destroyed while attached.
        private var keptEngineAttachedTo: BubbleActivity? = null

        private var trimCallbacks: ComponentCallbacks2? = null

        private fun watchForTrim(appContext: Context) {
            if (!DESTROY_KEPT_ENGINE_ON_TRIM || trimCallbacks != null) return
            val callbacks = object : ComponentCallbacks2 {
                override fun onTrimMemory(level: Int) {
                    if (isMemoryRequest(level)) destroyIdleKeptEngine(appContext, "trim level $level")
                }

                @Deprecated("Deprecated in Java")
                override fun onLowMemory() = destroyIdleKeptEngine(appContext, "low memory")

                override fun onConfigurationChanged(newConfig: Configuration) {}
            }
            appContext.registerComponentCallbacks(callbacks)
            trimCallbacks = callbacks
        }

        /// TRIM_MEMORY_UI_HIDDEN is left out: it arrives whenever a closed bubble was the only thing on screen,
        /// which would throw the engine away before the next bubble could use it. The RUNNING_* levels are only
        /// delivered before Android 14.
        @Suppress("DEPRECATION")
        private fun isMemoryRequest(level: Int): Boolean =
            level >= ComponentCallbacks2.TRIM_MEMORY_BACKGROUND ||
                level == ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW ||
                level == ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL

        private fun destroyIdleKeptEngine(appContext: Context, reason: String) {
            if (keptEngineHost != null || keptEngineAttachedTo != null) return
            val cache = FlutterEngineCache.getInstance()
            val engine = cache.get(KEPT_ENGINE_ID) ?: return
            cache.remove(KEPT_ENGINE_ID)
            engine.destroy()
            trimCallbacks?.let { appContext.unregisterComponentCallbacks(it) }
            trimCallbacks = null
            PersistentLog.i(appContext, Constants.logTag, "Destroyed the kept bubble engine ($reason)")
        }
    }

    private var usesKeptEngine = false

    override fun onCreate(savedInstanceState: Bundle?) {
        if (keptEngineHost == null) {
            keptEngineHost = this
            usesKeptEngine = true
            startKeptEngine()
        }
        super.onCreate(savedInstanceState)
    }

    private fun startKeptEngine() {
        if (FlutterEngineCache.getInstance().contains(KEPT_ENGINE_ID)) return
        val engine = FlutterEngine(applicationContext)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                DART_ENTRYPOINT
            )
        )
        FlutterEngineCache.getInstance().put(KEPT_ENGINE_ID, engine)
        watchForTrim(applicationContext)
    }

    override fun getCachedEngineId(): String? {
        return if (usesKeptEngine) KEPT_ENGINE_ID else null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (usesKeptEngine) keptEngineAttachedTo = this
        setMethodCallHandler(flutterEngine, this)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        if (!usesKeptEngine) return
        if (keptEngineAttachedTo === this) keptEngineAttachedTo = null
        // The kept engine outlives this activity and Dart still calls the channel after detaching
        // (the foreground service), so hand it the application context instead of this activity.
        setMethodCallHandler(flutterEngine, applicationContext)
    }

    private fun setMethodCallHandler(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.methodChannel).setMethodCallHandler {
                call, result -> MethodCallHandler().methodCallHandler(call, result, context)
        }
    }

    override fun getDartEntrypointFunctionName(): String {
        return DART_ENTRYPOINT
    }

    override fun onPause() {
        super.onPause()
        // onDestroy comes only after the next activity has drawn, too late for it to reuse the engine.
        if (isFinishing) releaseKeptEngine()
    }

    override fun onDestroy() {
        super.onDestroy()
        releaseKeptEngine()
        if (keptEngineAttachedTo === this) keptEngineAttachedTo = null
    }

    private fun releaseKeptEngine() {
        if (keptEngineHost === this) keptEngineHost = null
    }
}
