package com.bluebubbles.messaging.services.backend_ui_interop

import android.content.Context
import androidx.lifecycle.Observer
import androidx.work.BackoffPolicy
import androidx.work.Data
import androidx.work.OneTimeWorkRequest
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.WorkRequest
import java.io.File
import java.util.UUID
import java.util.concurrent.TimeUnit
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.utils.PersistentLog
import com.google.gson.GsonBuilder
import com.google.gson.ToNumberPolicy
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

object DartWorkManager {
    // androidx.work caps a serialized Data object at 10 KB (Data.MAX_DATA_BYTES) and throws
    // IllegalStateException out of build() when that's exceeded. Socket events routinely run
    // past it (a message with a long attributedBody, a chat with many participants), so
    // oversized payloads are spilled to a file in cacheDir and read back by the worker.
    // The threshold is conservative because the cap covers the whole serialized Data object —
    // keys, the method string, and per-entry overhead — not just the payload value.
    private const val MAX_INLINE_DATA_BYTES = 8 * 1024
    private const val PAYLOAD_DIR = "bluebubbles_worker_payloads"
    private const val PAYLOAD_TTL_MS = 24 * 60 * 60 * 1000L

    /// [callback] receives whether the Dart work actually SUCCEEDED. Callers must not
    /// treat completion as success: WorkManager also reaches a finished state on FAILED
    /// and CANCELLED, which is exactly what happens when a cold engine boot fails while
    /// the app is killed. Reporting those as success makes the UI claim work was done
    /// that never happened (e.g. a notification reply that was never sent).
    fun createWorker(context: Context, method: String, arguments: HashMap<String, Any?>, callback: (Boolean) -> (Unit)) {
        PersistentLog.d(context, Constants.logTag, "Creating new ${Constants.dartWorkerTag} for method $method")
        val gson = GsonBuilder()
            .setObjectToNumberStrategy(ToNumberPolicy.LONG_OR_DOUBLE)
            .create()

        val inputData = try {
            buildInputData(context, method, gson.toJson(arguments))
        } catch (e: Exception) {
            // Dropping the event is the only option left, but it must not kill the caller's
            // thread — for socket events that thread belongs to socket.io itself.
            PersistentLog.e(context, Constants.logTag, "Failed to build input data for method $method — dropping event", e)
            callback(false)
            return
        }

        val work = OneTimeWorkRequest.Builder(DartWorker::class.java)
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            // Retries redeliver dropped events (e.g. notifications). Exponential from the
            // 10s minimum (~10s/20s/40s/80s/160s) so the retry window spans ~5 minutes —
            // long enough to outlast a memory-pressure spike that makes cold engine boots
            // fail repeatedly, while the first retry still lands within seconds.
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, WorkRequest.MIN_BACKOFF_MILLIS, TimeUnit.MILLISECONDS)
            .setInputData(inputData)
            .addTag(Constants.dartWorkerTag)
            .build()
        WorkManager.getInstance(context).enqueue(work)

        // Observe when the worker is finished and run the provided callback.
        // Everything runs on the main thread (LiveData requirement), and we must hold
        // the ONE LiveData instance: getWorkInfoByIdLiveData returns a new instance per
        // call, so removing the observer from a second instance would be a no-op and
        // leak the observer (and its Room subscription) for the life of the process.
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val liveData = WorkManager.getInstance(context).getWorkInfoByIdLiveData(work.id)
                // WorkInfo? — the LiveData emits null once the work record is pruned;
                // a non-null Observer<WorkInfo> would NPE on that emission and crash the process.
                lateinit var observer: Observer<WorkInfo?>
                observer = Observer { workInfo ->
                    if (workInfo != null && !workInfo.state.isFinished) return@Observer
                    // Remove first (we're on the main thread, so this is synchronous) so a
                    // re-emission can't run the callback twice.
                    liveData.removeObserver(observer)
                    if (workInfo == null) {
                        PersistentLog.w(context, Constants.logTag, "Work record for method $method was pruned before completion was observed")
                        return@Observer
                    }
                    val succeeded = workInfo.state == WorkInfo.State.SUCCEEDED
                    if (!succeeded) {
                        PersistentLog.e(context, Constants.logTag, "Worker for method $method finished unsuccessfully (state: ${workInfo.state})")
                    }
                    PersistentLog.d(context, Constants.logTag, "Running callback after worker with method $method completed (state: ${workInfo.state})")
                    try {
                        callback(succeeded)
                    } catch (e: Exception) {
                        PersistentLog.e(context, Constants.logTag, "Error running callback for worker $method", e)
                    }
                }
                liveData.observeForever(observer)
            } catch (e: Exception) {
                PersistentLog.e(context, Constants.logTag, "Error observing worker $method", e)
            }
        }
    }

    /// Puts [json] straight into the work's input data when it comfortably fits, and spills it
    /// to disk otherwise. The worker reads back whichever key is present.
    private fun buildInputData(context: Context, method: String, json: String): Data {
        val size = json.toByteArray(Charsets.UTF_8).size
        if (size <= MAX_INLINE_DATA_BYTES) {
            try {
                return Data.Builder().putString("method", method).putString("data", json).build()
            } catch (e: IllegalStateException) {
                // Data serializes with Java's *modified* UTF-8, which is wider than the UTF-8
                // the size estimate above measures (supplementary chars — emoji — cost 6 bytes
                // there vs 4). Spill rather than trust the estimate.
                PersistentLog.w(context, Constants.logTag, "Payload for method $method exceeded the Data cap despite measuring $size bytes — spilling", e)
            }
        }

        val file = writePayload(context, json)
        PersistentLog.d(context, Constants.logTag, "Payload for method $method is $size bytes — spilled to ${file.name}")
        return Data.Builder().putString("method", method).putString("dataFile", file.absolutePath).build()
    }

    private fun writePayload(context: Context, json: String): File {
        val dir = File(context.cacheDir, PAYLOAD_DIR)
        dir.mkdirs()
        prunePayloads(context, dir)
        val file = File(dir, "${UUID.randomUUID()}.json")
        file.writeText(json, Charsets.UTF_8)
        return file
    }

    /// The worker deletes its own payload once it reaches a terminal state, but a process
    /// death between enqueue and completion would strand the file. Sweep on every spill —
    /// that path is rare, unlike enqueue itself.
    private fun prunePayloads(context: Context, dir: File) {
        try {
            val cutoff = System.currentTimeMillis() - PAYLOAD_TTL_MS
            dir.listFiles()?.forEach { if (it.lastModified() < cutoff) it.delete() }
        } catch (e: Exception) {
            PersistentLog.w(context, Constants.logTag, "Failed to prune stale worker payloads", e)
        }
    }

    /// Deletes a payload spilled by [buildInputData]. No-op when the payload was inlined
    /// (i.e. [path] is null). Must only be called once the work is finished for good — a
    /// retry re-reads the same file.
    fun deletePayload(context: Context, path: String?) {
        if (path == null) return
        try {
            File(path).delete()
        } catch (e: Exception) {
            PersistentLog.w(context, Constants.logTag, "Failed to delete spilled worker payload $path", e)
        }
    }
}