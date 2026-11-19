package com.bluebubbles.messaging.services.system

import android.annotation.SuppressLint
import android.content.Context
import android.provider.Settings
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// ANDROID_ID: kept across reinstalls, reset only by a factory reset or a different signing key
class AndroidIdHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "get-android-id"
    }

    @SuppressLint("HardwareIds")
    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        result.success(Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID))
    }
}
