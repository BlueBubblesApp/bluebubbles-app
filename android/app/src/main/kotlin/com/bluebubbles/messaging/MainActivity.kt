package com.bluebubbles.messaging

import android.app.Activity
import android.content.Intent
import androidx.activity.ComponentActivity
import com.bluebubbles.messaging.services.backend_ui_interop.MethodCallHandler
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
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

    override fun onDestroy() {
        engine = null
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == Constants.notificationListenerRequestCode) {
            MethodCallHandler.getNotificationListenerResult?.success(resultCode == Activity.RESULT_OK)
        }
    }
}