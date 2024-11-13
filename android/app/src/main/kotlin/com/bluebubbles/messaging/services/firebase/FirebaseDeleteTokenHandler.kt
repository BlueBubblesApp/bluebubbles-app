package com.bluebubbles.messaging.services.firebase

import android.content.Context
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FirebaseDeleteTokenHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "firebase-delete-token"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        FirebaseCloudMessagingTokenHandler().deleteToken(result)
    }
}