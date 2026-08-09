package com.bluebubbles.messaging.utils

import android.content.Context
import android.util.Log
import java.io.File
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.concurrent.Executors

/// General-purpose native-side logging facade mirroring the Dart Logger.
/// Each level function logs to logcat (as android.util.Log always has) and
/// also appends the entry to a rotating file inside the Flutter log directory,
/// so native logs survive logcat rollover and are included in the app's log
/// export (which zips every *.log in that folder), alongside the Dart logs.
/// Timestamps are UTC ISO-8601, matching the Dart Logger's convention.
object PersistentLog {
    private const val FILE_NAME = "native.log"
    private const val MAX_SIZE_BYTES = 2 * 1024 * 1024L
    private const val MAX_ROTATED_FILES = 2

    // Single-threaded so writes stay ordered and never block the caller.
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "PersistentLog").apply { isDaemon = true }
    }

    fun d(context: Context, tag: String, message: String) {
        Log.d(tag, message)
        persist(context, "DEBUG", tag, message, null)
    }

    fun i(context: Context, tag: String, message: String) {
        Log.i(tag, message)
        persist(context, "INFO", tag, message, null)
    }

    fun w(context: Context, tag: String, message: String, throwable: Throwable? = null) {
        if (throwable != null) Log.w(tag, message, throwable) else Log.w(tag, message)
        persist(context, "WARN", tag, message, throwable)
    }

    fun e(context: Context, tag: String, message: String, throwable: Throwable? = null) {
        if (throwable != null) Log.e(tag, message, throwable) else Log.e(tag, message)
        persist(context, "ERROR", tag, message, throwable)
    }

    private fun persist(context: Context, level: String, tag: String, message: String, throwable: Throwable?) {
        val appContext = context.applicationContext
        executor.execute {
            try {
                val dir = File(appContext.getDir("flutter", Context.MODE_PRIVATE), "logs")
                if (!dir.exists()) dir.mkdirs()

                val file = File(dir, FILE_NAME)
                if (file.exists() && file.length() > MAX_SIZE_BYTES) rotate(dir)

                val timestamp = DateTimeFormatter.ISO_INSTANT.format(Instant.now())
                val builder = StringBuilder()
                builder.append("$timestamp [$level] [$tag] $message\n")
                if (throwable != null) builder.append(throwable.stackTraceToString().trimEnd()).append('\n')

                file.appendText(builder.toString())
            } catch (e: Exception) {
                Log.e("PersistentLog", "Failed to write persistent log entry", e)
            }
        }
    }

    // Rotated files are named native.1.log, native.2.log, ... (not native.log.1) so
    // they still match the app's log export filter (files ending in ".log").
    private fun rotatedName(index: Int) = "native.$index.log"

    private fun rotate(dir: File) {
        val oldest = File(dir, rotatedName(MAX_ROTATED_FILES))
        if (oldest.exists()) oldest.delete()

        for (i in MAX_ROTATED_FILES - 1 downTo 1) {
            val src = File(dir, rotatedName(i))
            if (src.exists()) src.renameTo(File(dir, rotatedName(i + 1)))
        }

        File(dir, FILE_NAME).renameTo(File(dir, rotatedName(1)))
    }
}
