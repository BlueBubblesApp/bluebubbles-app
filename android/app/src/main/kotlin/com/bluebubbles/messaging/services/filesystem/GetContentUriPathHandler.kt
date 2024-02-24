package com.bluebubbles.messaging.services.filesystem

import android.content.Context
import android.net.Uri
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.utils.FilesystemUtils
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Fetches the actual path of a shared item with a content-uri path
class GetContentUriPathHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "get-content-uri-path"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val uri: String = call.argument("uri")!!
        result.success(FilesystemUtils.getAbsolutePath(context, Uri.parse(uri)))
    }
}