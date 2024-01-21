package com.bluebubbles.messaging.services.notifications

import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.service.notification.NotificationListenerService
import android.util.Log
import androidx.palette.graphics.Palette
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.services.backend_ui_interop.MethodCallHandler

/// Class used to listen for media notifications and fetch album art to update app theming
class NotificationListener: NotificationListenerService() {
    companion object {
        private var hasInit: Boolean = false;

        fun init(context: Context) {
            if (hasInit) return
            val manager: MediaSessionManager = context.getSystemService(MediaSessionManager::class.java)
            val sessionListener = MediaSessionListener()
            sessionListener.init(context)
            manager.addOnActiveSessionsChangedListener(sessionListener, ComponentName(context, this::class.java))
            hasInit = true;
        }
    }
}

class MediaSessionListener: MediaSessionManager.OnActiveSessionsChangedListener {
    companion object {
        val callback = MediaControllerCallback()
        var oldControllers: MutableList<MediaController> = mutableListOf()
    }

    fun init(context: Context) {
        Log.d(Constants.logTag, "Initializing media session listener...")
        val manager: MediaSessionManager = context.getSystemService(MediaSessionManager::class.java)
        val controllers = manager.getActiveSessions(ComponentName(context, NotificationListener::class.java))
        onActiveSessionsChanged(controllers)
    }

    override fun onActiveSessionsChanged(controllers: MutableList<MediaController>?) {
        if ((controllers?.size ?: 0) == 0) {
            return
        }

        Log.d(Constants.logTag, "Media session changed, unregistering and re-registering callbacks...")
        for (controller in oldControllers) {
            controller.unregisterCallback(callback)
        }
        oldControllers = controllers!!
        for (controller in controllers) {
            controller.registerCallback(callback)
        }
    }
}

class MediaControllerCallback: MediaController.Callback() {
    override fun onMetadataChanged(metadata: MediaMetadata?) {
        super.onMetadataChanged(metadata)
        if (metadata == null) return
        Log.d(Constants.logTag, "Media metadata changed (new track ${metadata.getString(MediaMetadata.METADATA_KEY_TITLE)})")
        val art = metadata.getBitmap(MediaMetadata.METADATA_KEY_ART)
        val albumArt = metadata.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)

        if (art != null || albumArt != null) {
            Log.d(Constants.logTag, "Fetching palette for new media")
            Palette.from((art ?: albumArt)!!).generate {palette ->
                val vibrant = palette?.vibrantSwatch?.rgb;
                if (vibrant != null) {
                    Log.d(Constants.logTag, "Sending primary color to Dart")
                    MethodCallHandler.invokeMethod("MediaColors", hashMapOf("primary" to vibrant))
                }
            }
        }
    }
}