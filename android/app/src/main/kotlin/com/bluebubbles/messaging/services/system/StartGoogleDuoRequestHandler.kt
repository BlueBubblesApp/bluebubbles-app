package com.bluebubbles.messaging.services.system

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Start a google duo call
class StartGoogleDuoRequestHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "google-duo"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val number: String = call.argument("number")!!
        val intent = Intent("${Constants.googleDuoPackageName}.action.CALL")
            .setPackage(Constants.googleDuoPackageName)
            .setData(Uri.parse("tel:${number}"))
        if (intent.resolveActivity(context.packageManager) != null) {
            context.startActivity(intent)
            result.success(null)
        } else {
            result.error("500", "Failed to find Google Duo!", null)
        }
    }
}