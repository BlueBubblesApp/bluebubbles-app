package com.bluebubbles.messaging.services.foreground

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.util.Log
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.R
import com.bluebubbles.messaging.services.backend_ui_interop.DartWorkManager
import io.socket.client.IO
import io.socket.client.Socket
import java.net.URISyntaxException
import org.json.JSONObject


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

    private var isBeingDestroyed: Boolean = false

    private val eventBlacklist: Array<String> = arrayOf(
        "typing-indicator",
        "chat-read-status-changed",
        "new-findmy-location",
        Socket.EVENT_CONNECT,
        Socket.EVENT_DISCONNECT
    )

    override fun onCreate() {
        super.onCreate()
        isBeingDestroyed = false

        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", 0)
        val serverUrl: String? = prefs.getString("flutter.serverAddress", null)
        val keepAppAlive: Boolean = prefs.getBoolean("flutter.keepAppAlive", false)
        val storedPassword: String? = prefs.getString("flutter.guidAuthKey", null)

        // Make sure the user has enabled the service
        if (!keepAppAlive) {
            Log.d(Constants.logTag, DISABLED)
            
            // Stop the service
            stopSelf()
            return
        }

        // Create notification for foreground service
        createNotificationChannel()
        startForeground(
            Constants.foregroundServiceNotificationId,
            createNotification(DEFAULT_NOTIFICATION)
        )

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
        try {
            Log.d(Constants.logTag, "Foreground Service is connecting to: $serverUrl")

            val opts = IO.Options()
            opts.query = "password=$storedPassword"
            mSocket = IO.socket(serverUrl, opts)
            mSocket!!.connect()

            mSocket!!.on(Socket.EVENT_CONNECT) {
                Log.d(Constants.logTag, "Socket.io connected to your server!")
                updateNotification(CONNECTED)
            }

            mSocket!!.on(Socket.EVENT_CONNECT_ERROR) { args ->
                val error = args[0] as Exception
                Log.d(Constants.logTag, "Socket.io failed to connect to $serverUrl! Error: ${error.message}")
                updateNotification(CONNECT_FAILED + error.message)
            }

            // with reason, details args
            mSocket!!.on(Socket.EVENT_DISCONNECT) { args ->
                val reason = args[0] as String
                Log.d(Constants.logTag, "Socket.io disconnected from server! Reason: $reason")
                if (isBeingDestroyed) {
                    return@on
                }

                val details = args.getOrNull(1)
                Log.d(Constants.logTag, "Socket.io disconnected from server! Reason: $reason, Details: $details")
                updateNotification(DISCONNECTED + reason)
            }

            mSocket!!.on("reconnecting") {
                Log.d(Constants.logTag, "Socket.io is reconnecting to your server...")
                updateNotification(RECONNECTING)
            }

            mSocket!!.on("reconnect_failed") {
                Log.d(Constants.logTag, "Socket.io failed to reconnect to your server...")
                updateNotification(RECONNECT_FAILED)
            }

            mSocket!!.onAnyIncoming { args ->
                if (args.isNotEmpty()) {
                    val event = args[0] as String
                    val message = args[1] as JSONObject

                    Log.d(Constants.logTag, "Received event of type $event from Socket.io...")
                    if (!eventBlacklist.contains(event)) {
                        Log.d(Constants.logTag, "Received event of type $event from Socket.io...")
                        DartWorkManager.createWorker(applicationContext, "socket-event", hashMapOf("event" to event, "data" to message.toString())) {}
                    } else {
                        Log.d(Constants.logTag, "Ignored event of type $event from Socket.io...")
                    }
                }
            }
        } catch (e: Exception) {
            if (isBeingDestroyed) {
                return
            }

            Log.e(Constants.logTag, "Socket.io unhandled error occurred!", e)
            updateNotification(UNHANDLED_ERROR)
            tryReconnect()
        }
    }

    private fun tryReconnect() {
        if (mSocket != null && !mSocket!!.connected()) {
            Log.e(Constants.logTag, "Waiting 30 seconds before reconnecting...")

            // Sleep for 30 seconds before attempting to reconnect
            Thread.sleep(30000)
            mSocket!!.connect()
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
        Log.d(Constants.logTag, "BlueBubbles Service is being destroyed!")

        super.onDestroy()
        mSocket?.disconnect()
        mSocket?.close()

        // Remove the notification when the service is destroyed
        removeNotification()
    }
}
