package com.bluebubbles.messaging

import android.util.Log
import android.app.Activity
import android.content.Intent
import androidx.activity.ComponentActivity
import com.bluebubbles.messaging.services.backend_ui_interop.MethodCallHandler
import com.bluebubbles.messaging.services.foreground.ForegroundServiceBroadcastReceiver
import com.bluebubbles.messaging.Constants
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        var engine: FlutterEngine? = null
    }

    private var methodChannel: MethodChannel? = null
    private var dartReady = false
    private val pendingFaceTimeIntents = mutableListOf<Pair<String, Map<String, Any>>>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        engine = flutterEngine
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Constants.methodChannel)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "ready") {
                dartReady = true
                result.success(null)
                flushPendingFaceTimeIntents()
            } else {
                MethodCallHandler().methodCallHandler(call, result, this)
            }
        }
        handleFaceTimeIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleFaceTimeIntent(intent)
    }

    override fun onDestroy() {
        Log.d(Constants.logTag, "BlueBubbles MainActivity is being destroyed")
        engine = null

        // If we are finishing "gracefully", the dart code would have started the foreground service.
        // If we are finishing because the system is destroying the activity, we need to start the foreground service
        // via a broadcast intent.
        if (isFinishing) {
            Log.d(Constants.logTag, "BlueBubbles activity is finishing")
        } else {
            Log.d(Constants.logTag, "BlueBubbles activity is being destroyed by the system")

            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", 0)
            val keepAppAlive: Boolean = prefs.getBoolean("flutter.keepAppAlive", false)

            // Create an intent to start the foreground service
            if (keepAppAlive) {
                Log.d(Constants.logTag, "Creating broadcast intent to restart the foreground service...")
                val broadcastIntent = Intent(this, ForegroundServiceBroadcastReceiver::class.java)
                broadcastIntent.setAction("restartservice");
                sendBroadcast(broadcastIntent);
            }
        }

        try {
            super.onDestroy()
        } catch (e: ConcurrentModificationException) {
            Log.d(Constants.logTag, "Caught ConcurrentModificationException when destroying MainActivity")
            Log.e(Constants.logTag, e.stackTraceToString())
        } catch (e: Exception) {
            Log.d(Constants.logTag, "Caught unhandled Exception when destroying MainActivity")
            Log.e(Constants.logTag, e.stackTraceToString())
        }
    }

    private fun handleFaceTimeIntent(intent: Intent?) {
        val callUuid = intent?.getStringExtra("callUuid") ?: return
        val caller = intent.getStringExtra("caller") ?: "Unknown"
        val isAudio = intent.getBooleanExtra("isAudio", false)
        val answer = intent.getBooleanExtra("answer", false)
        val method = if (answer) "answer-facetime" else "show-facetime-overlay"
        val arguments = mapOf(
            "callUuid" to callUuid,
            "caller" to caller,
            "isAudio" to isAudio
        )

        if (dartReady) {
            Log.d(Constants.logTag, "Forwarding FaceTime notification intent to Dart")
            methodChannel?.invokeMethod(method, arguments)
        } else {
            Log.d(Constants.logTag, "Queueing FaceTime notification intent until Dart is ready")
            pendingFaceTimeIntents.add(Pair(method, arguments))
        }
    }

    private fun flushPendingFaceTimeIntents() {
        if (pendingFaceTimeIntents.isEmpty()) return
        Log.d(Constants.logTag, "Flushing ${pendingFaceTimeIntents.size} pending FaceTime notification intent(s)")
        val pending = pendingFaceTimeIntents.toList()
        pendingFaceTimeIntents.clear()
        pending.forEach { (method, arguments) ->
            methodChannel?.invokeMethod(method, arguments)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == Constants.notificationListenerRequestCode) {
            MethodCallHandler.getNotificationListenerResult?.success(resultCode == Activity.RESULT_OK)
        }
    }
}
