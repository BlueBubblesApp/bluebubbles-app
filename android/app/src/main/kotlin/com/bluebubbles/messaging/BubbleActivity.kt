package com.bluebubbles.messaging

import android.os.Bundle
import com.bluebubbles.messaging.services.backend_ui_interop.MethodCallHandler
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

        private val engineLock = Any()
        @Volatile private var _engine: FlutterEngine? = null

        // An engine draws for one activity at a time; other bubbles get their own.
        private var keptEngineHost: BubbleActivity? = null
        
        fun getEngine(): FlutterEngine? {
            synchronized(engineLock) {
                return _engine
            }
        }
        
        fun setEngine(newEngine: FlutterEngine?) {
            synchronized(engineLock) {
                _engine = newEngine
            }
        }
    }

    private var usesKeptEngine = false

    override fun onCreate(savedInstanceState: Bundle?) {
        synchronized(engineLock) {
            if (keptEngineHost == null) {
                keptEngineHost = this
                usesKeptEngine = true
                startKeptEngine()
            }
        }
        super.onCreate(savedInstanceState)
    }

    // The embedding does not run a cached engine's entrypoint.
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
    }

    override fun getCachedEngineId(): String? {
        return if (usesKeptEngine) KEPT_ENGINE_ID else null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        setEngine(flutterEngine)
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.methodChannel).setMethodCallHandler {
                call, result -> MethodCallHandler().methodCallHandler(call, result, this)
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
        setEngine(null)
        super.onDestroy()
        releaseKeptEngine()
    }

    private fun releaseKeptEngine() {
        synchronized(engineLock) {
            if (keptEngineHost === this) keptEngineHost = null
        }
    }
}