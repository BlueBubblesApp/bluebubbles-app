package com.bluebubbles.messaging.utils

import android.content.Context
import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import androidx.core.graphics.drawable.IconCompat
import com.bluebubbles.messaging.services.firebase.FirebaseAuthHandler
import com.bluebubbles.messaging.services.firebase.ServerUrlRequestHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object Utils {
    fun getAdaptiveIconFromByteArray(data: ByteArray): IconCompat {
        val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size)
        // Scale the bitmap to 108x108dp to comply with adaptive icon guidelines
        // Start by scaling the inner image to 72x72dp
        var width = bitmap.width
        var height = bitmap.height
        val aspectRatio = width / height
        if (aspectRatio > 1) {
            width = (72 * Resources.getSystem().displayMetrics.density).toInt()
            height = width / aspectRatio
        } else {
            height = (72 * Resources.getSystem().displayMetrics.density).toInt()
            width = height / aspectRatio
        }
        val scaledBitmap = Bitmap.createScaledBitmap(bitmap, width, height, true)
        // Add transparent padding to achieve 108x108dp
        val padding = ((108 - 72) * Resources.getSystem().displayMetrics.density).toInt();
        val adaptiveBitmap = Bitmap.createBitmap(scaledBitmap.width + padding, scaledBitmap.height + padding, Bitmap.Config.ARGB_8888)
        val tempCanvas = Canvas(adaptiveBitmap)
        tempCanvas.drawBitmap(scaledBitmap, (padding / 2).toFloat(), (padding / 2).toFloat(), null)
        return IconCompat.createWithAdaptiveBitmap(adaptiveBitmap)
    }

    fun getServerUrl(context: Context, password: String, result: MethodChannel.Result) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", 0)
        val storedPassword = prefs.getString("flutter.guidAuthKey", "")
        if (password != storedPassword) return

        val fcmData = HashMap<String, String?>()
        fcmData["project_id"] = prefs.getString("flutter.projectID", "")
        fcmData["storage_bucket"] = prefs.getString("flutter.storageBucket", "")
        fcmData["api_key"] = prefs.getString("flutter.apiKey", "")
        fcmData["firebase_url"] = prefs.getString("flutter.firebaseURL", "")
        fcmData["client_id"] = prefs.getString("flutter.clientID", "")
        fcmData["application_id"] = prefs.getString("flutter.applicationID", "")
        val map: Map<String, String?> = HashMap(fcmData)
        FirebaseAuthHandler().handleMethodCall(MethodCall("", map), object : MethodChannel.Result {
            override fun success(temp: Any?) {
                ServerUrlRequestHandler().handleMethodCall(MethodCall("", null), result, context)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        }, context)
    }
}