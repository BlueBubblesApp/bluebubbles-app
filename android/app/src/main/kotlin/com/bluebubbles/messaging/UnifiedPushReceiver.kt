package com.bluebubbles.messaging

import com.bluebubbles.messaging.services.backend_ui_interop.DartWorkManager
import com.bluebubbles.messaging.utils.Utils
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.ToNumberPolicy
import com.google.gson.reflect.TypeToken

import org.unifiedpush.android.connector.MessagingReceiver
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.core.os.bundleOf

class UnifiedPushReceiver : MessagingReceiver() {
    companion object {
        const val tag: String = "UnifiedPushReceiver"
    }

    override fun onNewEndpoint(context: Context, endpoint: String, instance: String) {
        Log.d(tag, "New endpoint: $endpoint")

        val data = HashMap<String, Any?>();
        data["endpoint"] = endpoint;
        DartWorkManager.createWorker(context, "unifiedpush-settings", data) {}
    }

    override fun onRegistrationFailed(context: Context, instance: String) {
        Log.d(tag, "Registration Failed")
        val data = HashMap<String, Any?>();
        data["endpoint"] = "";
        DartWorkManager.createWorker(context, "unifiedpush-settings", data) {}
    }

    override fun onUnregistered(context: Context, instance: String) {
        Log.d(tag, "Unregistered endpoint")
        val data = HashMap<String, Any?>();
        data["endpoint"] = "";
        DartWorkManager.createWorker(context, "unifiedpush-settings", data) {}
    }

    inline fun <reified T> Gson.fromJson(json: String) = fromJson<T>(json, object: TypeToken<T>() {}.type)

    override fun onMessage(context: Context, payload: ByteArray, instance: String) {
        val applicationContext = context.getApplicationContext()
        val msg = payload.toString(Charsets.UTF_8)
        Log.i(tag, "UnifiedPush payload received (${payload.size} bytes)")

        try {
            val gson: Gson = GsonBuilder()
                .setObjectToNumberStrategy(ToNumberPolicy.LONG_OR_DOUBLE)
                .create()
            @Suppress("UNCHECKED_CAST")
            val parsed = gson.fromJson<HashMap<String, Any?>>(
                msg,
                object : TypeToken<HashMap<String, Any?>>() {}.type,
            )
            val type: String = parsed["type"]?.toString() ?: run {
                Log.w(tag, "UnifiedPush payload missing type field (${payload.size} bytes)")
                return
            }

            Log.i(tag, "Received new message of type $type from UnifiedPush (${payload.size} bytes)")
            DartWorkManager.createWorker(applicationContext, type, parsed) {}

            // check if the user configured "Send Events to Tasker"
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", 0)
            if (prefs.getBoolean("flutter.sendEventsToTasker", false)) {
                Utils.getServerUrl(applicationContext, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        Log.w(tag, "Got URL: $result - sending to Tasker...")
                        val intent = Intent()
                        intent.setAction("net.dinglisch.android.taserm.BB_EVENT")
                        intent.putExtra("url", result.toString())
                        intent.putExtra("event", type)
                        intent.putExtras(bundleOf(*parsed.toList().toTypedArray()))
                        applicationContext.sendBroadcast(intent)
                    }

                    override fun error(errorCode: String, errorMesage: String?, errorDetails: Any?) {}
                    override fun notImplemented() {}
                })
            }
        } catch (e: Exception) {
            Log.e(tag, "Failed to process UnifiedPush message (${payload.size} bytes)", e)
        }
    }
}