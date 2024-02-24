package com.bluebubbles.messaging.services.system

import android.content.Context
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Launch given URL in a Chrome Custom Tab
class BrowserLaunchRequestHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "open-browser"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val link: String = call.argument("link")!!
        val intent: CustomTabsIntent = CustomTabsIntent.Builder()
            .setSendToExternalDefaultHandlerEnabled(false)
            .build()
        intent.launchUrl(context, Uri.parse(link))
        result.success(null)
    }
}