package com.bluebubbles.messaging.services.notifications

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.service.notification.NotificationListenerService
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.services.backend_ui_interop.MethodCallHandler

import java.io.ByteArrayOutputStream

/// Class used to listen for media notifications and fetch album art to update app theming
class NotificationListener: NotificationListenerService() {
    companion object {
        private var hasInit: Boolean = false

        fun init(context: Context) {
            if (hasInit) return
            val manager: MediaSessionManager = context.getSystemService(MediaSessionManager::class.java)
            val sessionListener = MediaSessionListener()
            sessionListener.init(context)
            manager.addOnActiveSessionsChangedListener(sessionListener, ComponentName(context, this::class.java))
            hasInit = true
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
            Log.d(Constants.logTag, "Sending album art to Dart")
            val stream = ByteArrayOutputStream()
            (art ?: albumArt)!!.compress(Bitmap.CompressFormat.PNG, 100, stream)
            val byteArray = stream.toByteArray()
            MethodCallHandler.invokeMethod("MediaColors", hashMapOf("albumArt" to byteArray))
            stream.flush()
        }
    }
}