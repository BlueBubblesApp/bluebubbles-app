package com.bluebubbles.messaging

import android.content.Context
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

        private var keptEngineHost: BubbleActivity? = null
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
    }

    override fun getCachedEngineId(): String? {
        return if (usesKeptEngine) KEPT_ENGINE_ID else null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setMethodCallHandler(flutterEngine, this)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        // The kept engine outlives this activity and Dart still calls the channel after detaching
        // (the foreground service), so hand it the application context instead of this activity.
        if (usesKeptEngine) setMethodCallHandler(flutterEngine, applicationContext)
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
    }

    private fun releaseKeptEngine() {
        if (keptEngineHost === this) keptEngineHost = null
    }
}