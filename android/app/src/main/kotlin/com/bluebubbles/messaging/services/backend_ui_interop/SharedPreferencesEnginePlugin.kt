package com.bluebubbles.messaging.services.backend_ui_interop

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin

/**
 * Owns the preferences JNI registration across the activity, bubble, and worker engines.
 *
 * shared_preferences_android 2.5.x uses process-wide registrars: attaching a second stock
 * plugin replaces the first registration, and detaching either removes it for every engine.
 * The upstream plugin only needs application context, so share one delegate until the last
 * engine detaches. Do not retain a binding (and therefore an engine) in the shared owner.
 */
class SharedPreferencesEnginePlugin : FlutterPlugin {
    private var attached = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        synchronized(lock) {
            check(!attached) { "Preferences wrapper already attached" }
            if (engineCount == 0) {
                val plugin = SharedPreferencesPlugin()
                plugin.onAttachedToEngine(binding)
                delegate = plugin
            }
            engineCount++
            attached = true
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        synchronized(lock) {
            if (!attached) return
            attached = false
            engineCount--
            if (engineCount == 0) {
                try {
                    delegate?.onDetachedFromEngine(binding)
                } finally {
                    delegate = null
                }
            }
        }
    }

    private companion object {
        val lock = Any()
        var engineCount = 0
        var delegate: SharedPreferencesPlugin? = null
    }
}
