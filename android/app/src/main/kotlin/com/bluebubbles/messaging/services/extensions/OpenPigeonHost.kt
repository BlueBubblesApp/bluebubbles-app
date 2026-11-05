package com.bluebubbles.messaging.services.extensions

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import android.widget.RemoteViews
import com.bluebubbles.messaging.IKeyboardHandle
import com.bluebubbles.messaging.IMadridExtension
import com.bluebubbles.messaging.IMessageViewHandle
import com.bluebubbles.messaging.ITaskCompleteCallback
import com.bluebubbles.messaging.IViewUpdateCallback
import com.bluebubbles.messaging.MadridMessage
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout

/// Host side of the Madrid extension interface, for OpenPigeon (com.openbubbles.openpigeon).
/// OpenPigeon supplies RemoteViews for the game picker and game bubbles; turns it produces
/// are handed to Dart, which sends them through the server's app-message route.
object OpenPigeonHost {
    const val PACKAGE = "com.openbubbles.openpigeon"
    private const val SERVICE = "$PACKAGE.MadridExtensionService"
    private const val TAG = "OpenPigeonHost"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var channel: MethodChannel? = null
    private var extension: CompletableDeferred<IMadridExtension>? = null

    /// Views on screen, which are loaded again if OpenPigeon's process dies: its sessions die with it, and a view's
    /// tap would open a game it no longer knows. Main thread only.
    private val views = mutableSetOf<ExtensionView>()

    fun register(engine: FlutterEngine, context: Context) {
        val app = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.bluebubbles.messaging/openpigeon").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "installed" -> result.success(isInstalled(app))
                    "message-updated" -> {
                        val message = madridMessage(call.arguments as? Map<*, *> ?: emptyMap<Any, Any>())
                        withExtension(app) { it.messageUpdated(message) }
                        result.success(null)
                    }
                    "open" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        val message = madridMessage(args)
                        val handle = messageHandle(args["chatGuid"] as? String ?: "")
                        val userCount = (args["userCount"] as? Number)?.toInt() ?: 2
                        withExtension(app) { it.didTapTemplate(message, handle, userCount) }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        val registry = engine.platformViewsController.registry
        registry.registerViewFactory("openpigeon/live", ViewFactory(keyboard = false))
        registry.registerViewFactory("openpigeon/keyboard", ViewFactory(keyboard = true))
    }

    private fun isInstalled(context: Context): Boolean = try {
        context.packageManager.getPackageInfo(PACKAGE, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    /// The binder dies with OpenPigeon's process, so a dropped connection is unbound and the
    /// next call binds afresh.
    private fun connect(context: Context): CompletableDeferred<IMadridExtension> = synchronized(this) {
        extension?.let { return it }
        val deferred = CompletableDeferred<IMadridExtension>()
        extension = deferred
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder) {
                deferred.complete(IMadridExtension.Stub.asInterface(binder))
            }

            override fun onServiceDisconnected(name: ComponentName?) = drop(reload = true)
            override fun onBindingDied(name: ComponentName?) = drop(reload = true)
            override fun onNullBinding(name: ComponentName?) = drop(reload = false)

            private fun drop(reload: Boolean) {
                reset(deferred)
                try {
                    context.unbindService(this)
                } catch (_: IllegalArgumentException) {}
                if (reload) main.postDelayed({ views.toList().forEach { it.load() } }, 1_000)
            }
        }
        val bound = context.bindService(Intent().setClassName(PACKAGE, SERVICE), connection, Context.BIND_AUTO_CREATE)
        if (!bound) reset(deferred)
        deferred
    }

    private fun reset(deferred: CompletableDeferred<IMadridExtension>) {
        synchronized(this) { if (extension === deferred) extension = null }
        deferred.completeExceptionally(IllegalStateException("OpenPigeon disconnected"))
    }

    // OpenPigeon is a separate app that can change under us, so anything it does wrong is logged, never thrown
    private fun withExtension(context: Context, onError: () -> Unit = {}, block: (IMadridExtension) -> Unit) =
        scope.launch {
            try {
                block(withTimeout(10_000) { connect(context).await() })
            } catch (e: Exception) {
                Log.e(TAG, "OpenPigeon call failed", e)
                onError()
            }
        }

    // Needs the activity's Dart engine alive; a turn played after the app was killed is left
    // to OpenPigeon's own retry.
    private fun send(chatGuid: String, message: MadridMessage, fromKeyboard: Boolean, done: () -> Unit = {}) {
        main.post {
            val args = mapOf(
                "chatGuid" to chatGuid,
                "fromKeyboard" to fromKeyboard,
                "url" to message.url,
                "session" to message.session,
                "ldText" to message.ldText,
                "caption" to message.caption,
                "imageBase64" to message.imageBase64,
            )
            channel?.invokeMethod("send", args, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    scope.launch { done() }
                }

                override fun error(code: String, msg: String?, details: Any?) {
                    Log.e(TAG, "Sending OpenPigeon message failed: $code $msg")
                }

                override fun notImplemented() {}
            })
        }
    }

    /// Where OpenPigeon sends a game's turns. It keeps the handle on its session and uses it from the game activity,
    /// so it can't depend on any view.
    private fun messageHandle(chatGuid: String) = object : IMessageViewHandle.Stub() {
        override fun updateMessage(message: MadridMessage?, callback: ITaskCompleteCallback?) {
            if (message == null) return
            send(chatGuid, message, fromKeyboard = false) {
                try {
                    callback?.complete()
                } catch (e: Exception) {
                    Log.w(TAG, "OpenPigeon completion callback failed", e)
                }
            }
        }

        override fun setSuppressNotifications(suppress: Boolean) {}
        override fun lock() {}
        override fun unlock() {}
    }

    private fun madridMessage(map: Map<*, *>) = MadridMessage().apply {
        messageGuid = map["messageGuid"] as? String ?: ""
        url = map["url"] as? String ?: ""
        session = map["session"] as String?
        ldText = map["ldText"] as String?
        caption = map["caption"] as String?
        isLive = true
    }

    private class ViewFactory(private val keyboard: Boolean) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
            ExtensionView(context, keyboard, viewId, args as? Map<*, *> ?: emptyMap<Any, Any>())
    }

    private class ExtensionView(
        private val context: Context,
        private val keyboard: Boolean,
        private val viewId: Int,
        args: Map<*, *>,
    ) : PlatformView {
        private val container = FrameLayout(context)
        @Volatile private var disposed = false
        @Volatile private var failed = false
        private val chatGuid = args["chatGuid"] as? String ?: ""

        private val viewCallback = object : IViewUpdateCallback.Stub() {
            override fun updateView(views: RemoteViews?) = show(views)
        }

        private val keyboardHandle = object : IKeyboardHandle.Stub() {
            override fun addMessage(message: MadridMessage?) {
                if (message != null) send(chatGuid, message, fromKeyboard = true)
            }
        }
        private val messageHandle = messageHandle(chatGuid)

        private val userCount = (args["userCount"] as? Number)?.toInt() ?: 2
        private val message = if (keyboard) null else madridMessage(args)

        init {
            views.add(this)
            load()
            // A view that never arrives counts as a failure too
            main.postDelayed({ if (container.childCount == 0) fail() }, 15_000)
        }

        /// Asks OpenPigeon for this view, which also (re)creates its session there.
        fun load() {
            if (disposed || failed) return
            withExtension(context.applicationContext, ::fail) {
                show(
                    if (keyboard) it.keyboardOpened(viewCallback, keyboardHandle, userCount)
                    else it.getLiveView(viewCallback, message, messageHandle, userCount)
                )
            }
        }

        private fun show(views: RemoteViews?) {
            if (views == null) return fail()
            main.post {
                if (disposed) return@post
                try {
                    container.removeAllViews()
                    container.addView(views.apply(context, container))
                } catch (e: Exception) {
                    Log.e(TAG, "Applying OpenPigeon views failed", e)
                    fail()
                }
            }
        }

        /// Tells Dart to show its own fallback in place of this view.
        private fun fail() {
            main.post {
                if (disposed || failed) return@post
                failed = true
                channel?.invokeMethod("view-failed", mapOf("id" to viewId))
            }
        }

        override fun getView(): View = container

        override fun dispose() {
            disposed = true
            views.remove(this)
            if (keyboard) withExtension(context.applicationContext) { it.keyboardClosed() }
        }
    }
}
