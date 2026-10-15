package com.bluebubbles.messaging

import com.bluebubbles.messaging.services.backend_ui_interop.MethodCallHandler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class BubbleActivity : FlutterFragmentActivity() {
    companion object {
        private val engineLock = Any()
        @Volatile private var _engine: FlutterEngine? = null
        
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        setEngine(flutterEngine)
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.methodChannel).setMethodCallHandler {
                call, result -> MethodCallHandler().methodCallHandler(call, result, this)
        }
    }

    override fun getDartEntrypointFunctionName(): String {
        return "bubble"
    }

    override fun onDestroy() {
        setEngine(null)
        super.onDestroy()
    }
}