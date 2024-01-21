package com.bluebubbles.messaging.services.backend_ui_interop

import android.content.Context
import android.util.Log
import androidx.lifecycle.Observer
import androidx.work.Data
import androidx.work.OneTimeWorkRequest
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkInfo
import androidx.work.WorkManager
import com.bluebubbles.messaging.Constants
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

object DartWorkManager {
    fun createWorker(context: Context, method: String, arguments: HashMap<String, Any?>, callback: () -> (Unit)) {
        Log.d(Constants.logTag, "Creating new ${Constants.dartWorkerTag} for method $method")
        val work = OneTimeWorkRequest.Builder(DartWorker::class.java)
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            .setInputData(Data.Builder()
                .putString("method", method)
                .putAll(arguments).build())
            .addTag(Constants.dartWorkerTag)
            .build()
        WorkManager.getInstance(context).enqueue(work)

        // Observe when the worker is finished and run the provided callback
        lateinit var observer: Observer<WorkInfo>
        observer = Observer { workInfo ->
            if (workInfo.state.isFinished) {
                Log.d(Constants.logTag, "Running callback after worker with method $method completed")
                callback()
                CoroutineScope(Dispatchers.Main).launch {
                    WorkManager.getInstance(context).getWorkInfoByIdLiveData(work.id).removeObserver(observer)
                }
            }
        }
        // Cannot observe unless running on main thread
        CoroutineScope(Dispatchers.Main).launch {
            WorkManager.getInstance(context).getWorkInfoByIdLiveData(work.id).observeForever(observer)
        }
    }
}