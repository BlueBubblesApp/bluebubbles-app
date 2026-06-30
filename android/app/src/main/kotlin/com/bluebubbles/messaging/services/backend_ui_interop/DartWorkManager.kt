package com.bluebubbles.messaging.services.backend_ui_interop

import android.content.Context
import android.util.Log
import androidx.lifecycle.Observer
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkInfo
import androidx.work.WorkManager
import com.bluebubbles.messaging.Constants
import com.google.gson.GsonBuilder
import com.google.gson.ToNumberPolicy
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File

object DartWorkManager {
    // WorkManager input data is capped at 10 KB total; attachment pushes can exceed that.
    private const val WORKER_DATA_MAX_BYTES = 9_000
    const val DATA_FILE_MARKER = "@file:"

    fun createWorker(context: Context, method: String, arguments: HashMap<String, Any?>, callback: () -> (Unit)) {
        Log.d(Constants.logTag, "Creating new ${Constants.dartWorkerTag} for method $method")
        val gson = GsonBuilder()
            .setObjectToNumberStrategy(ToNumberPolicy.LONG_OR_DOUBLE)
            .create()
        val json = gson.toJson(arguments)
        Log.i(Constants.logTag, "Worker payload for $method is ${json.length} bytes")

        val dataBuilder = Data.Builder().putString("method", method)
        if (json.length <= WORKER_DATA_MAX_BYTES) {
            dataBuilder.putString("data", json)
        } else {
            val payloadFile = File(
                context.cacheDir,
                "dart_worker_${System.currentTimeMillis()}_${method.hashCode()}.json",
            )
            payloadFile.writeText(json)
            dataBuilder.putString("data", DATA_FILE_MARKER + payloadFile.absolutePath)
            Log.w(
                Constants.logTag,
                "Worker payload exceeds WorkManager limit; spilling ${json.length} bytes to ${payloadFile.absolutePath}",
            )
        }

        val work = OneTimeWorkRequest.Builder(DartWorker::class.java)
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            .setInputData(dataBuilder.build())
            .addTag(Constants.dartWorkerTag)
            .build()
        // Use unique work to prevent a binder storm when multiple FCM messages arrive
        // simultaneously (e.g. after waking from sleep). Parallel enqueue() calls each
        // trigger separate JobScheduler binder calls, which can exceed Android's cached-process
        // threshold and cause the OS to kill the process before any message is processed.
        // APPEND_OR_REPLACE chains jobs sequentially (safe: workerEngine is a singleton) and
        // keeps all messages — unlike KEEP (drops) or REPLACE (cancels in-progress work).
        try {
            WorkManager.getInstance(context).enqueueUniqueWork(
                Constants.dartWorkerTag,
                ExistingWorkPolicy.APPEND_OR_REPLACE,
                work
            )
        } catch (e: Exception) {
            Log.e(Constants.logTag, "Failed to enqueue worker for method $method (${json.length} bytes)", e)
            if (json.length > WORKER_DATA_MAX_BYTES) {
                val spilledPath = dataBuilder.build().getString("data")
                if (spilledPath?.startsWith(DATA_FILE_MARKER) == true) {
                    File(spilledPath.removePrefix(DATA_FILE_MARKER)).delete()
                }
            }
            return
        }

        // Observe when the worker is finished and run the provided callback
        lateinit var observer: Observer<WorkInfo>
        observer = Observer { workInfo ->
            if (workInfo.state.isFinished) {
                Log.d(Constants.logTag, "Running callback after worker with method $method completed (state: ${workInfo.state})")
                try {
                    callback()
                } catch (e: Exception) {
                    Log.e(Constants.logTag, "Error running callback for worker $method", e)
                }
                CoroutineScope(Dispatchers.Main).launch {
                    try {
                        WorkManager.getInstance(context).getWorkInfoByIdLiveData(work.id).removeObserver(observer)
                    } catch (e: Exception) {
                        Log.e(Constants.logTag, "Error removing observer for worker $method", e)
                    }
                }
            }
        }
        // Cannot observe unless running on main thread
        CoroutineScope(Dispatchers.Main).launch {
            try {
                WorkManager.getInstance(context).getWorkInfoByIdLiveData(work.id).observeForever(observer)
            } catch (e: Exception) {
                Log.e(Constants.logTag, "Error observing worker $method", e)
            }
        }
    }
}