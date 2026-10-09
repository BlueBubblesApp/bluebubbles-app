package com.bluebubbles.messaging.utils

import android.os.Debug

/// Memory figures for this process, in KB, read straight from the kernel via Debug.getMemoryInfo.
///
/// That call is used instead of ActivityManager.getProcessMemoryInfo because the latter has been
/// rate-limited to one real sample per five minutes since Android 10 and silently returns stale
/// numbers in between, which would make before/after comparisons meaningless.
object MemoryStats {
    fun snapshot(): HashMap<String, Long> {
        val info = Debug.MemoryInfo()
        Debug.getMemoryInfo(info)
        return hashMapOf(
            "pss" to info.totalPss.toLong(),
            "graphics" to stat(info, "summary.graphics"),
            "javaHeap" to stat(info, "summary.java-heap"),
            "nativeHeap" to stat(info, "summary.native-heap"),
            "code" to stat(info, "summary.code"),
            "privateOther" to stat(info, "summary.private-other"),
        )
    }

    fun describe(): String {
        val s = snapshot()
        return "pss=${mb(s["pss"])} graphics=${mb(s["graphics"])} " +
            "java=${mb(s["javaHeap"])} native=${mb(s["nativeHeap"])}"
    }

    private fun stat(info: Debug.MemoryInfo, key: String): Long = info.getMemoryStat(key)?.toLongOrNull() ?: -1L

    private fun mb(kb: Long?): String = if (kb == null || kb < 0) "?" else String.format("%.1fMB", kb / 1024.0)
}
