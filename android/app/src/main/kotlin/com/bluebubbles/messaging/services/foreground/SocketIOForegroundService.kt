package com.bluebubbles.messaging.services.foreground

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.R
import com.bluebubbles.messaging.services.backend_ui_interop.DartWorkManager
import com.bluebubbles.messaging.utils.PersistentLog
import io.socket.client.IO
import io.socket.client.Socket
import java.net.URISyntaxException
import java.net.URLEncoder
import org.json.JSONObject
import java.util.Collections.singletonList


class SocketIOForegroundService : Service() {

    companion object {
        // Consts for notification messages
        const val DEFAULT_NOTIFICATION = "BlueBubbles is running in the background."
        const val MISSING_SERVER_URL = "BlueBubbles Service is missing your server URL!"
        const val MISSING_PASSWORD = "BlueBubbles Service is missing your password!"
        const val UNHANDLED_ERROR = "BlueBubbles Service encountered an unhandled error"
        const val CONNECTED = "BlueBubbles is connected to your server!"
        const val CONNECT_FAILED = "BlueBubbles failed to connect to your server! Error: "
        const val DISCONNECTED = "BlueBubbles is disconnected from your server! Error: "
        const val RECONNECTING = "BlueBubbles is reconnecting to your server..."
        const val RECONNECT_FAILED = "BlueBubbles failed to reconnect to your server..."
        const val DESTROYED = "BlueBubbles Service was destroyed!"
        const val DISABLED = "BlueBubbles Foreground Service is disabled"
    }

    private var mSocket: Socket? = null

    private var currentNotification: String? = null

    @Volatile
    private var isBeingDestroyed: Boolean = false

    @Volatile
    private var hasStarted: Boolean = false

    // A single-shot Handler used for scheduled reconnect attempts. Using a Handler
    // + named Runnable allows us to (a) prevent multiple concurrent reconnect
    // threads from accumulating and (b) cancel any pending reconnect when the
    // service is destroyed.
    private val reconnectHandler = Handler(Looper.getMainLooper())
    private val reconnectRunnable = Runnable {
        reconnectScheduled = false
        if (!isBeingDestroyed && mSocket != null && !mSocket!!.connected()) {
            PersistentLog.e(applicationContext, Constants.logTag, "Attempting reconnection now...")
            mSocket!!.connect()
        }
    }

    @Volatile
    private var reconnectScheduled: Boolean = false

    private val eventBlacklist: Array<String> = arrayOf(
        "typing-indicator",
        "new-findmy-location",
        Socket.EVENT_CONNECT,
        Socket.EVENT_DISCONNECT
    )

    override fun onCreate() {
        super.onCreate()
        isBeingDestroyed = false

        try {
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", 0)
            val serverUrl: String? = prefs.getString("serverAddress", null)
            val keepAppAlive: Boolean = prefs.getBoolean("keepAppAlive", false)
            val storedPassword: String? = prefs.getString("guidAuthKey", null)
            val customHeaders: String? = prefs.getString("customHeaders", null)

            // Make sure the user has enabled the service
            if (!keepAppAlive) {
                PersistentLog.d(applicationContext, Constants.logTag, DISABLED)
                
                // Stop the service
                stopSelf()
                return
            }

            // Create notification for foreground service
            createNotificationChannel()
            ServiceCompat.startForeground(
                this,
                Constants.foregroundServiceNotificationId,
                createNotification(DEFAULT_NOTIFICATION),
                FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING
            )

            hasStarted = true

            // if the service is enabled, but the server URL is missing, update the notification
            if (serverUrl == null || serverUrl.isEmpty()) {
                updateNotification(MISSING_SERVER_URL)
                return
            }

            // if the service is enabled, but the password is missing, update the notification
            if (storedPassword == null || storedPassword.isEmpty()) {
                updateNotification(MISSING_PASSWORD)
                return
            }

            // Initialize socket.io connection
            PersistentLog.d(applicationContext, Constants.logTag, "Foreground Service is connecting to: $serverUrl")

            val opts = IO.Options()

            try {
                // Read the custom headers JSON string from preferences and parse it into a map
                val extraHeaders = mutableMapOf<String, List<String>>()
                val customHeaderMap = JSONObject(customHeaders)
                customHeaderMap.keys().forEach { key ->
                    // Add the key-value pair to extraHeaders
                    extraHeaders[key] = singletonList(customHeaderMap.getString(key))
                }
                opts.extraHeaders = extraHeaders
            } catch (e: Exception) {
                PersistentLog.e(applicationContext, Constants.logTag, "Failed to parse custom headers JSON string!", e)
            }

            // Only log the headers if they are not null or empty
            if (opts.extraHeaders != null && opts.extraHeaders.isNotEmpty()) {
                PersistentLog.d(applicationContext, Constants.logTag, "Socket.io Custom headers: ${opts.extraHeaders}")
            }

            val encodedPw = URLEncoder.encode(storedPassword, "UTF-8")
            opts.query = "password=$encodedPw"
            mSocket = IO.socket(serverUrl, opts)
            mSocket!!.connect()

            mSocket!!.on(Socket.EVENT_CONNECT) {
                PersistentLog.d(applicationContext, Constants.logTag, "Socket.io connected to your server!")
                updateNotification(CONNECTED)
            }

            mSocket!!.on(Socket.EVENT_CONNECT_ERROR) { args ->
                val error = args[0] as Exception
                PersistentLog.d(applicationContext, Constants.logTag, "Socket.io failed to connect to $serverUrl! Error: ${error.message}")
                updateNotification(CONNECT_FAILED + error.message)
            }

            // with reason, details args
            mSocket!!.on(Socket.EVENT_DISCONNECT) { args ->
                val reason = args[0] as String
                PersistentLog.d(applicationContext, Constants.logTag, "Socket.io disconnected from server! Reason: $reason")
                if (isBeingDestroyed) {
                    return@on
                }

                val details = args.getOrNull(1)
                PersistentLog.d(applicationContext, Constants.logTag, "Socket.io disconnected from server! Reason: $reason, Details: $details")
                updateNotification(DISCONNECTED + reason)
            }

            mSocket!!.on("reconnecting") {
                PersistentLog.d(applicationContext, Constants.logTag, "Socket.io is reconnecting to your server...")
                updateNotification(RECONNECTING)
            }

            mSocket!!.on("reconnect_failed") {
                PersistentLog.d(applicationContext, Constants.logTag, "Socket.io failed to reconnect to your server...")
                updateNotification(RECONNECT_FAILED)
            }

            mSocket!!.onAnyIncoming { args ->
                if (args.isNotEmpty()) {
                    val event = args[0] as String
                    val message = args[1] as JSONObject

                    PersistentLog.d(applicationContext, Constants.logTag, "Received event of type $event from Socket.io...")
                    if (!eventBlacklist.contains(event)) {
                        PersistentLog.d(applicationContext, Constants.logTag, "Received event of type $event from Socket.io...")
                        DartWorkManager.createWorker(applicationContext, "socket-event", hashMapOf("event" to event, "data" to message.toString())) {}
                    } else {
                        PersistentLog.d(applicationContext, Constants.logTag, "Ignored event of type $event from Socket.io...")
                    }
                }
            }
        } catch (e: Exception) {
            if (isBeingDestroyed) {
                return
            }

            PersistentLog.e(applicationContext, Constants.logTag, "Socket.io unhandled error occurred!", e)
            updateNotification(UNHANDLED_ERROR)

            if (hasStarted) {
                tryReconnect()
            }
        }
    }

    private fun tryReconnect() {
        // Guard: if a reconnect is already pending, don't schedule another one.
        if (reconnectScheduled) {
            PersistentLog.d(applicationContext, Constants.logTag, "Reconnect already scheduled, skipping.")
            return
        }
        val socket = mSocket
        if (socket != null && !socket.connected()) {
            reconnectScheduled = true
            PersistentLog.e(applicationContext, Constants.logTag, "Scheduling reconnection in 30 seconds...")
            reconnectHandler.postDelayed(reconnectRunnable, 30_000L)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                Constants.foregroundServiceNotificationChannel,
                "BlueBubbles Foreground Service",
                NotificationManager.IMPORTANCE_MIN
            )

            // This channel should not vibrate or make sound
            channel.setSound(null, null)
            channel.enableVibration(false)

            // Create the channel
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(contentText: String): Notification {
        currentNotification = contentText
        return NotificationCompat.Builder(this, Constants.foregroundServiceNotificationChannel)
            .setContentTitle("BlueBubbles Service")
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_stat_icon)
            // The notification should be categorized as silent
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            // The notification should be ongoing and not cancelable.
            // This does not prevent dismissing it on Android 14+.
            .setOngoing(true)
            // The notification should not alert the user
            .setOnlyAlertOnce(true)
            // The notification should not cancel when the user taps on it
            .setAutoCancel(false)
            // The notification should not show the time
            .setShowWhen(false)
            .setColor(4888294)
            .build()
    }

    private fun updateNotification(contentText: String) {
        // If the notification is the same, don't update it
        if (currentNotification == contentText) {
            return
        }

        val notification = createNotification(contentText)
        val notificationManager = getSystemService(NotificationManager::class.java) as NotificationManager
        notificationManager.notify(Constants.foregroundServiceNotificationId, notification)
    }

    private fun removeNotification() {
        val notificationManager = getSystemService(NotificationManager::class.java) as NotificationManager
        notificationManager.cancel(Constants.foregroundServiceNotificationId)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        isBeingDestroyed = true
        hasStarted = false
        reconnectScheduled = false
        reconnectHandler.removeCallbacks(reconnectRunnable)
        PersistentLog.d(applicationContext, Constants.logTag, "BlueBubbles Service is being destroyed!")

        super.onDestroy()
        mSocket?.disconnect()
        mSocket?.close()

        // Remove the notification when the service is destroyed
        removeNotification()
    }
}
