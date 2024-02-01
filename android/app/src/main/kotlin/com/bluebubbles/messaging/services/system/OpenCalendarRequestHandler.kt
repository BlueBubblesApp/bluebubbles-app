package com.bluebubbles.messaging.services.system

import android.content.Context
import android.content.Intent
import android.provider.CalendarContract
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Create a new event in the calendar
class OpenCalendarRequestHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "open-calendar"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val begin: Long = call.argument("date")!!
        val intent = Intent(Intent.ACTION_EDIT)
            .setType("vnd.android.cursor.item/event")
            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, begin)
            .putExtra("finishActivityOnSaveCompleted", true)
        context.startActivity(intent)
        result.success(null)
    }
}