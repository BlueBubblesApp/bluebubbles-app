package com.bluebubbles.messaging.services.system

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.MainActivity
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.utils.MemoryStats
import com.bluebubbles.messaging.utils.PersistentLog
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Purges the Flutter engine's own caches: GPU textures, the Skia/Impeller resource cache and
/// unused Dart VM heap pages. This is exactly what FlutterActivityAndFragmentDelegate does when
/// the OS delivers a TRIM_MEMORY_RUNNING_LOW-or-worse callback; Dart's CacheService calls it
/// directly so the purge happens on our schedule and gets logged with before/after numbers,
/// rather than depending on whether Android chose to send a trim.
///
/// Only the main engine is purged. The headless DartWorker engine is short-lived and never
/// registers the CacheService that would call this.
class TrimMemoryHandler : MethodCallHandlerImpl() {
    companion object {
        const val tag = "trim-memory"

        /// How long to wait before sampling memory again. The GC and GPU release the purge kicks
        /// off are asynchronous, so an immediate sample would just repeat the "before" number.
        private const val SETTLE_DELAY_MS = 1500L
    }

    override fun handleMethodCall(call: MethodCall, result: MethodChannel.Result, context: Context) {
        try {
            val engine = MainActivity.getEngine()
            if (engine == null) {
                PersistentLog.w(context, Constants.logTag, "$tag: no main engine attached, nothing to purge")
                result.success(false)
                return
            }

            val before = MemoryStats.describe()
            engine.dartExecutor.notifyLowMemoryWarning()
            engine.systemChannel.sendMemoryPressureWarning()
            PersistentLog.d(context, Constants.logTag, "$tag: engine purge requested, before: $before")

            Handler(Looper.getMainLooper()).postDelayed({
                val after = MemoryStats.describe()
                PersistentLog.d(context, Constants.logTag, "$tag: after settle: $after (before: $before)")
            }, SETTLE_DELAY_MS)

            result.success(true)
        } catch (e: Exception) {
            PersistentLog.e(context, Constants.logTag, "$tag: failed to purge engine caches", e)
            result.error("TRIM_MEMORY_ERROR", e.message, e)
        }
    }
}
