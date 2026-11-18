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

        // One engine is kept between bubbles, in FlutterEngineCache under this id, so that
        // opening a bubble does not run the app's whole startup again (database, contacts,
        // themes, chats) before its first frame. Dart learns which chat the next bubble is
        // for from that activity's intent (IntentsService listens to
        // ReceiveIntent.receivedIntentStream).
        private const val KEPT_ENGINE_ID = "bubble"

        private val engineLock = Any()
        @Volatile private var _engine: FlutterEngine? = null

        // The bubble the kept engine is drawing for. An engine draws for one activity at a
        // time, so a bubble opened while another still exists starts an engine of its own,
        // destroyed with it, as every bubble did before.
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

    // Whether this bubble draws with the kept engine. Decided in onCreate, before
    // FlutterFragmentActivity builds its fragment and asks for getCachedEngineId().
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

    // A cached engine is expected to be running Dart already: the embedding only starts
    // the entrypoint of engines it creates itself.
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

    // A cached engine is not destroyed with the activity (shouldDestroyEngineWithHost).
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
        // A bubble that is closing gives the engine up now: Android delays onDestroy until
        // the next activity has drawn, and a bubble opened right after this one should not
        // have to start an engine of its own. The embedding detaches a cached engine from
        // its previous activity when the next one attaches (detachFromFlutterEngine).
        if (isFinishing) releaseKeptEngine()
    }

    override fun onDestroy() {
        setEngine(null)
        super.onDestroy()
        // After super: the fragment has detached from the engine by now.
        releaseKeptEngine()
    }

    private fun releaseKeptEngine() {
        synchronized(engineLock) {
            if (keptEngineHost === this) keptEngineHost = null
        }
    }
}