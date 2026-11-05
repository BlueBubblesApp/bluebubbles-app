package com.bluebubbles.messaging.services.system

import android.content.Context
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.utils.MemoryStats
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Returns this process's current memory figures in KB (see MemoryStats.snapshot) so the
/// developer tools page can show what a purge actually freed without adb.
class MemoryStatsHandler : MethodCallHandlerImpl() {
    companion object {
        const val tag = "memory-stats"
    }

    override fun handleMethodCall(call: MethodCall, result: MethodChannel.Result, context: Context) {
        try {
            result.success(MemoryStats.snapshot())
        } catch (e: Exception) {
            result.error("MEMORY_STATS_ERROR", e.message, e)
        }
    }
}
