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

data class BBServerInfo(val url: String?, val guid: String?)

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

    fun getServerUrl(context: Context, result: MethodChannel.Result) {
        FirebaseAuthHandler().handleMethodCall(MethodCall("", null), object : MethodChannel.Result {
            override fun success(temp: Any?) {
                ServerUrlRequestHandler().handleMethodCall(MethodCall("", null), result, context)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        }, context)
    }

    fun getBBServerUrl(context: Context): BBServerInfo {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", 0)

        return BBServerInfo(
            prefs.getString("flutter.serverAddress", null),
            prefs.getString("flutter.guidAuthKey", null)
        )
    }
}