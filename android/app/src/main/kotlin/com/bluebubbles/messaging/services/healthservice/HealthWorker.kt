package com.bluebubbles.messaging.services.healthservice

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.bluebubbles.messaging.services.notifications.ConnectionErrorNotification
import com.bluebubbles.messaging.utils.BBServerInfo
import com.bluebubbles.messaging.utils.Utils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import java.io.IOException
import java.net.HttpURLConnection

import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.TimeUnit
import kotlin.time.DurationUnit
import kotlin.time.toDuration


class HealthWorker(val context: Context, params: WorkerParameters): CoroutineWorker(context, params) {
    private val networkObserver = NetworkObserver(context)

    private enum class ResultType {
        NO_INTERNET,
        PING_FAILURE,
        SUCCESS
    }

    override suspend fun doWork(): Result {
        return withContext(Dispatchers.IO) {
            networkObserver.start()

            networkObserver.internetState.first { it != NetworkObserver.ConnectionState.UNKNOWN }

            val result = when(pingWithRetries()) {
                ResultType.PING_FAILURE -> {
                    Log.w(TAG, "Server did not respond to pings!")
                    ConnectionErrorNotification().createErrorNotification(context)
                    Result.failure()
                }
                ResultType.NO_INTERNET -> {
                    Log.i(TAG, "Not checking health - no internet retry later")
                    Result.retry()
                }
                else -> {
                    ConnectionErrorNotification().clearErrorNotification(context)

                    Result.success()
                }
            }

            networkObserver.stop()

            return@withContext result
        }
    }

    private suspend fun pingWithRetries(): ResultType {
        return withContext(Dispatchers.IO) {
            var retryCounter = MAX_RETRIES;
            do {
                if (networkObserver.internetState.value == NetworkObserver.ConnectionState.DISCONNECTED) {
                    return@withContext ResultType.NO_INTERNET
                }

                val info = Utils.getBBServerUrl(context)

                try {
                    if (info.url == null || info.guid == null) {
                        Log.w(TAG, "Cannot ping - no server info")

                        throw IOException("No URL or GUID available")
                    }

                    Log.i(TAG, "Attempting to ping server")
                    pingServer(info)
                    return@withContext ResultType.SUCCESS
                } catch (e: IOException) {
                    Log.i(TAG, "Ping failed: ${e.message}")
                    --retryCounter
                    if (retryCounter > 0) delay(RETRY_DELAY)
                }
            } while (retryCounter > 0)

            return@withContext ResultType.PING_FAILURE
        }
    }

    private suspend fun pingServer(info: BBServerInfo) {
        withContext(Dispatchers.IO) {
            val parameters = mapOf(
                "guid" to info.guid
            )

            val paramsStr = parameters.keys.joinToString("&") { k ->
                "${URLEncoder.encode(k, "UTF-8")}=${URLEncoder.encode(parameters[k], "UTF-8")}"
            }

            val url = URL("${info.url}/api/v1/ping?$paramsStr")
            val con = url.openConnection() as HttpURLConnection
            con.requestMethod = "GET"

            con.disconnect()

            if (con.responseCode != 200) {
                throw IOException("Server responded with unsuccessful status ${con.responseCode}")
            } else {
                Log.i(TAG, "Successfully pinged server")
            }
        }
    }

    companion object {
        private const val TAG = "HealthWorker"
        private const val WORK_NAME = "HealthWorker"

        private const val MAX_RETRIES = 3
        private val RETRY_DELAY = 5.toDuration(DurationUnit.SECONDS)

        private const val REPEAT_MINUTES = 30L

        fun registerHealthChecking(context: Context) {
            Log.i(TAG, "Health checking enabled")

            val work = PeriodicWorkRequestBuilder<HealthWorker>(REPEAT_MINUTES, TimeUnit.MINUTES)
                .setConstraints(Constraints
                    .Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()
                )
                .addTag(TAG)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                work)
        }

        fun cancelHealthChecking(context: Context) {
            Log.i(TAG, "Health checking disabled")

            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}