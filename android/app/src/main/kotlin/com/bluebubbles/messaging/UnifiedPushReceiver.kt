package com.bluebubbles.messaging

import com.bluebubbles.messaging.services.backend_ui_interop.DartWorkManager
import com.bluebubbles.messaging.utils.PersistentLog
import com.bluebubbles.messaging.utils.Utils
import com.google.gson.JsonParseException
import com.google.gson.JsonParser
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonToken
import java.io.StringReader

import org.unifiedpush.android.connector.MessagingReceiver
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.core.os.bundleOf

class UnifiedPushReceiver : MessagingReceiver() {
    companion object {
        const val tag: String = "UnifiedPushReceiver"
    }

    override fun onNewEndpoint(context: Context, endpoint: String, instance: String) {
        PersistentLog.d(context, tag, "New endpoint: $endpoint")

        val data = HashMap<String, Any?>();
        data["endpoint"] = endpoint;
        DartWorkManager.createWorker(context, "unifiedpush-settings", data) {}
    }

    override fun onRegistrationFailed(context: Context, instance: String) {
        PersistentLog.d(context, tag, "Registration Failed")
        val data = HashMap<String, Any?>();
        data["endpoint"] = "";
        DartWorkManager.createWorker(context, "unifiedpush-settings", data) {}
    }

    override fun onUnregistered(context: Context, instance: String) {
        PersistentLog.d(context, tag, "Unregistered endpoint")
        val data = HashMap<String, Any?>();
        data["endpoint"] = "";
        DartWorkManager.createWorker(context, "unifiedpush-settings", data) {}
    }

    override fun onMessage(context: Context, payload: ByteArray, instance: String) {
        val applicationContext = context.getApplicationContext()
        val msg = payload.toString(Charsets.UTF_8)

        try {
            val json = try {
                JsonParser.parseString(msg).asJsonObject
            } catch (e: JsonParseException) {
                forwardCutOffMessage(applicationContext, msg, payload.size, e)
                return
            }
            val type: String = json.get("type")?.takeIf { it.isJsonPrimitive }?.asString ?: run {
                PersistentLog.w(applicationContext, tag, "UnifiedPush payload missing type field (${payload.size} bytes)")
                return
            }

            // Hand Dart the same shape FCM does. The server's webhook body carries `data` as a nested
            // object, while its FCM payload carries the same data JSON-encoded as a string, which Dart
            // decodes into the Map<String, dynamic> its parsers expect. A nested object instead crosses
            // the platform channel as Map<Object?, Object?>, and Attachment.fromMap can't take that as
            // its metadata, so every message whose attachment had metadata (most images) was dropped.
            val arguments = hashMapOf<String, Any?>(
                "type" to type,
                "data" to json.get("data")?.takeUnless { it.isJsonNull }?.toString(),
            )

            PersistentLog.i(applicationContext, tag, "Received new message of type $type from UnifiedPush (${payload.size} bytes)")
            DartWorkManager.createWorker(applicationContext, type, arguments) {}

            // check if the user configured "Send Events to Tasker"
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", 0)
            if (prefs.getBoolean("sendEventsToTasker", false)) {
                Utils.getServerUrl(applicationContext, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        PersistentLog.w(applicationContext, tag, "Got URL: $result - sending to Tasker...")
                        val intent = Intent()
                        intent.setAction("net.dinglisch.android.taskerm.BB_EVENT")
                        intent.putExtra("url", result.toString())
                        intent.putExtra("event", type)
                        intent.putExtras(bundleOf(*arguments.toList().toTypedArray()))
                        applicationContext.sendBroadcast(intent)
                    }

                    override fun error(errorCode: String, errorMesage: String?, errorDetails: Any?) {}
                    override fun notImplemented() {}
                })
            }
        } catch (e: Exception) {
            PersistentLog.e(applicationContext, tag, "Failed to process UnifiedPush message (${payload.size} bytes)", e)
        }
    }

    /**
     * ntfy cuts UnifiedPush messages off at 4096 bytes, so a message with a long attachment list
     * arrives as broken JSON. The server writes `type` first and the message's `guid` near the
     * start of `data`, so both survive the cut: forward just those, and Dart fetches the full
     * message from the server.
     */
    private fun forwardCutOffMessage(context: Context, msg: String, size: Int, error: Exception) {
        var type: String? = null
        var guid: String? = null
        try {
            val reader = JsonReader(StringReader(msg))
            reader.beginObject()
            while (reader.hasNext() && (type == null || guid == null)) {
                when (reader.nextName()) {
                    "type" -> type = reader.nextString()
                    "data" -> if (reader.peek() == JsonToken.BEGIN_OBJECT) {
                        reader.beginObject()
                        while (reader.hasNext() && guid == null) {
                            if (reader.nextName() == "guid") guid = reader.nextString() else reader.skipValue()
                        }
                    } else {
                        reader.skipValue()
                    }
                    else -> reader.skipValue()
                }
            }
        } catch (_: Exception) {
            // Expected once the reader reaches the cut; keep whatever was read before it.
        }

        val messageType = type
        val messageGuid = guid
        if (messageGuid == null || (messageType != "new-message" && messageType != "updated-message")) {
            PersistentLog.e(context, tag, "Failed to process UnifiedPush message ($size bytes)", error)
            return
        }

        PersistentLog.w(context, tag, "UnifiedPush $messageType payload was cut off ($size bytes); fetching message $messageGuid from the server")
        DartWorkManager.createWorker(context, messageType, hashMapOf<String, Any?>("type" to messageType, "guid" to messageGuid)) {}
    }
}
