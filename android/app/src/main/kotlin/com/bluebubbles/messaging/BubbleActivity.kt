package com.bluebubbles.messaging

import com.bluebubbles.messaging.services.backend_ui_interop.MethodCallHandler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class BubbleActivity : FlutterFragmentActivity() {
    companion object {
        var engine: FlutterEngine? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        engine = flutterEngine
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.methodChannel).setMethodCallHandler {
                call, result -> MethodCallHandler().methodCallHandler(call, result, this)
        }
    }

    override fun getDartEntrypointFunctionName(): String {
        return "bubble"
    }

    override fun onDestroy() {
        engine = null
        super.onDestroy()
    }
}