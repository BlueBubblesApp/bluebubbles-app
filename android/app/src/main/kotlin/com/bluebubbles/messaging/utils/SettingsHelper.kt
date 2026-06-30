package com.bluebubbles.messaging.utils

import android.content.Context
import android.content.SharedPreferences

/**
 * Helper class to access Flutter SharedPreferences settings from Kotlin.
 * Mirrors the Settings class from lib/database/global/settings.dart
 */
class SettingsHelper(private val context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    
    companion object {
        // Flutter's shared_preferences plugin stores all keys with this prefix in FlutterSharedPreferences.
        // Every other Kotlin service (SocketIOForegroundService, FirebaseAuthHandler, etc.) uses this prefix.
        private const val PREFIX = "flutter."
    }

    // Server connection settings
    val serverAddress: String
        get() = prefs.getString("${PREFIX}serverAddress", "") ?: ""
    
    val guidAuthKey: String
        get() = prefs.getString("${PREFIX}guidAuthKey", "") ?: ""
    
    val customHeaders: Map<String, String>
        get() {
            val headersJson = prefs.getString("${PREFIX}customHeaders", "{}") ?: "{}"
            return try {
                com.google.gson.Gson().fromJson(headersJson, Map::class.java) as? Map<String, String> ?: emptyMap()
            } catch (e: Exception) {
                emptyMap()
            }
        }
    
    val apiTimeout: Int
        get() {
            return try {
                // Flutter stores integers as Long, so we need to handle both cases
                prefs.getLong("${PREFIX}apiTimeout", 30000L).toInt()
            } catch (e: Exception) {
                try {
                    prefs.getInt("${PREFIX}apiTimeout", 30000)
                } catch (e: Exception) {
                    30000
                }
            }
        }
    
    // Private API settings
    val enablePrivateAPI: Boolean
        get() = prefs.getBoolean("${PREFIX}enablePrivateAPI", false)
    
    val privateAPISend: Boolean
        get() = prefs.getBoolean("${PREFIX}privateAPISend", false)
    
    val privateAPIAttachmentSend: Boolean
        get() = prefs.getBoolean("${PREFIX}privateAPIAttachmentSend", false)
    
    // Notification reaction settings
    val notificationReactionAction: Boolean
        get() = prefs.getBoolean("${PREFIX}notificationReactionAction", false)
    
    val notificationReactionActionType: String
        get() = prefs.getString("${PREFIX}notificationReactionActionType", "like") ?: "like"
    
    // Other useful settings
    val sendEventsToTasker: Boolean
        get() = prefs.getBoolean("${PREFIX}sendEventsToTasker", false)
    
    /**
     * Get the origin (base URL) from the server address
     */
    val origin: String
        get() {
            val address = serverAddress
            if (address.isEmpty()) return ""
            
            return try {
                val uri = android.net.Uri.parse(address)
                if (uri.scheme != null && uri.host != null) {
                    "${uri.scheme}://${uri.host}${if (uri.port != -1) ":${uri.port}" else ""}"
                } else {
                    ""
                }
            } catch (e: Exception) {
                ""
            }
        }
    
    /**
     * Get the API root URL
     */
    val apiRoot: String
        get() = "$origin/api/v1"
    
    /**
     * Check if the server URL is set
     */
    fun hasServerUrl(): Boolean = serverAddress.isNotEmpty()
    
    /**
     * Check if authentication key is set
     */
    fun hasAuthKey(): Boolean = guidAuthKey.isNotEmpty()
    
    /**
     * Get all headers that should be sent with requests
     */
    fun getAllHeaders(): Map<String, String> {
        val headers = customHeaders.toMutableMap()
        
        // Add special headers for certain services
        if (serverAddress.contains("ngrok")) {
            headers["ngrok-skip-browser-warning"] = "true"
        } else if (serverAddress.contains("zrok")) {
            headers["skip_zrok_interstitial"] = "true"
        }
        
        return headers
    }
}
