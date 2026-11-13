package com.bluebubbles.messaging.services.system

import android.content.ClipboardManager
import android.content.Context
import android.text.Html
import android.text.Spanned
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// The clipboard's formatting as HTML, or null for plain text. Most apps copy styled text (spans) rather than an
/// HTML clip; coerceToStyledText reads either, and Html.toHtml spells the spans as tags Dart's htmlRuns() parses.
class ClipboardHtmlHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag: String = "clipboard-html"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = clipboard.primaryClip
        val styled = if (clip != null && clip.itemCount > 0) clip.getItemAt(0).coerceToStyledText(context) else null
        result.success(
            if (styled is Spanned) Html.toHtml(styled, Html.TO_HTML_PARAGRAPH_LINES_CONSECUTIVE) else null
        )
    }
}
