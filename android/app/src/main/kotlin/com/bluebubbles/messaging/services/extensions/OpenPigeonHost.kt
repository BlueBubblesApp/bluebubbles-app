package com.bluebubbles.messaging.services.extensions

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
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
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/// Host side of the Madrid extension interface, for OpenPigeon (com.openbubbles.openpigeon).
/// OpenPigeon supplies RemoteViews for the game picker, and opens a game when its bubble is tapped; turns it
/// produces are handed to Dart, which sends them through the server's app-message route.
object OpenPigeonHost {
    const val PACKAGE = "com.openbubbles.openpigeon"
    private const val SERVICE = "$PACKAGE.MadridExtensionService"
    private const val TAG = "OpenPigeonHost"

    /// One thread, so calls reach OpenPigeon in the order they were made: a picker closed and reopened must not have
    /// its keyboardClosed land after the new keyboardOpened.
    private val scope = CoroutineScope(
        SupervisorJob() + Executors.newSingleThreadExecutor { Thread(it, TAG) }.asCoroutineDispatcher(),
    )
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var channel: MethodChannel? = null
    private var extension: CompletableDeferred<IMadridExtension>? = null
    private var connection: ServiceConnection? = null

    /// Picker views on screen, which are loaded again if OpenPigeon's process dies, since their sessions die with it.
    /// Main thread only.
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
                        val handle = messageHandle(args["chatGuid"] as? String ?: "", args["balloonBundleId"] as? String)
                        val userCount = (args["userCount"] as? Number)?.toInt() ?: 2
                        // Answered once OpenPigeon has taken it, so Dart can say when the game didn't open
                        withExtension(app, {
                            main.post { result.error("unavailable", "OpenPigeon couldn't open the game", null) }
                        }) {
                            it.didTapTemplate(message, handle, userCount)
                            main.post { result.success(null) }
                        }
                    }
                    // A still of a game's live view, for turns that carry no image of their own. Width and maxHeight
                    // are logical pixels; the reply is PNG bytes, or null.
                    "snapshot" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        val message = madridMessage(args)
                        val userCount = (args["userCount"] as? Number)?.toInt() ?: 2
                        val density = app.resources.displayMetrics.density
                        val width = ((args["width"] as? Number)?.toDouble() ?: 0.0).times(density).toInt()
                        val maxHeight = ((args["maxHeight"] as? Number)?.toDouble() ?: 0.0).times(density).toInt()
                        withExtension(app, { main.post { result.success(null) } }) {
                            val views = it.getLiveView(ignoredViewUpdates, message, inertHandle, userCount)
                            // Views are built on the main thread; the PNG is encoded off it
                            val bitmap = views?.let { v ->
                                withContext(Dispatchers.Main) { draw(app, v, width, maxHeight) }
                            }
                            val png = bitmap?.let { b -> withContext(Dispatchers.Default) { encode(b) } }
                            main.post { result.success(png) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        engine.platformViewsController.registry.registerViewFactory("openpigeon/keyboard", ViewFactory())
    }

    /// A snapshot is taken once, so later updates to its view are dropped.
    private val ignoredViewUpdates = object : IViewUpdateCallback.Stub() {
        override fun updateView(views: RemoteViews?) {}
    }

    /// The handle a snapshot's live view gets. Drawing a bubble is not the user playing, so nothing sent through it
    /// goes out; only a game the user opened gets a handle that sends.
    private val inertHandle = object : IMessageViewHandle.Stub() {
        override fun updateMessage(message: MadridMessage?, callback: ITaskCompleteCallback?) {
            Log.w(TAG, "Ignoring a message sent from a snapshot's view")
        }

        override fun setSuppressNotifications(suppress: Boolean) {}
        override fun lock() {}
        override fun unlock() {}
    }

    /// Lays [views] out off screen [width] pixels wide and draws them. The height is the layout's own, up to
    /// [maxHeight], so the bubble keeps the shape OpenPigeon draws. Main thread only.
    private fun draw(context: Context, views: RemoteViews, width: Int, maxHeight: Int): Bitmap? {
        if (width <= 0 || maxHeight <= 0) return null
        return try {
            val view = views.apply(context, FrameLayout(context))
            view.measure(
                View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(maxHeight, View.MeasureSpec.AT_MOST),
            )
            view.layout(0, 0, view.measuredWidth, view.measuredHeight)
            if (view.measuredWidth <= 0 || view.measuredHeight <= 0) return null
            Bitmap.createBitmap(view.measuredWidth, view.measuredHeight, Bitmap.Config.ARGB_8888).also {
                view.draw(Canvas(it))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Rendering an OpenPigeon view failed", e)
            null
        }
    }

    /// [bitmap] as PNG bytes, which then frees it.
    private fun encode(bitmap: Bitmap): ByteArray? = try {
        ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
    } catch (e: Exception) {
        Log.e(TAG, "Encoding an OpenPigeon view failed", e)
        null
    } finally {
        bitmap.recycle()
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
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder) {
                deferred.complete(IMadridExtension.Stub.asInterface(binder))
            }

            override fun onServiceDisconnected(name: ComponentName?) = drop(reload = true)
            override fun onBindingDied(name: ComponentName?) = drop(reload = true)
            override fun onNullBinding(name: ComponentName?) = drop(reload = false)

            private fun drop(reload: Boolean) {
                reset(context, deferred)
                if (reload) main.postDelayed({ views.toList().forEach { it.load() } }, 1_000)
            }
        }
        extension = deferred
        this.connection = connection
        // Tapping a game makes OpenPigeon open its own activity, which Android 14+ blocks from a background app unless
        // the visible app that bound it allows it
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Context.BIND_AUTO_CREATE or Context.BIND_ALLOW_ACTIVITY_STARTS
        } else {
            Context.BIND_AUTO_CREATE
        }
        val bound = try {
            context.bindService(Intent().setClassName(PACKAGE, SERVICE), connection, flags)
        } catch (e: SecurityException) {
            Log.e(TAG, "Binding OpenPigeon was refused", e)
            false
        }
        if (!bound) reset(context, deferred)
        deferred
    }

    /// Fails [deferred] and, if it is still the current binding, forgets and unbinds it so the next call binds afresh.
    /// A binding that never connects is reset the same way, or every later call would wait on it.
    private fun reset(context: Context, deferred: CompletableDeferred<IMadridExtension>) {
        val stale = synchronized(this) {
            if (extension !== deferred) {
                null
            } else {
                extension = null
                connection.also { connection = null }
            }
        }
        deferred.completeExceptionally(IllegalStateException("OpenPigeon disconnected"))
        if (stale != null) {
            try {
                context.unbindService(stale)
            } catch (_: IllegalArgumentException) {}
        }
    }

    // OpenPigeon is a separate app that can change under us, so anything it does wrong is logged, never thrown
    private fun withExtension(context: Context, onError: () -> Unit = {}, block: suspend (IMadridExtension) -> Unit) =
        scope.launch {
            try {
                val deferred = connect(context)
                val ext = try {
                    withTimeout(10_000) { deferred.await() }
                } catch (e: TimeoutCancellationException) {
                    reset(context, deferred)
                    throw e
                }
                block(ext)
            } catch (e: Exception) {
                Log.e(TAG, "OpenPigeon call failed", e)
                onError()
            }
        }

    // Needs the activity's Dart engine alive; a turn played after the app was killed is left
    // to OpenPigeon's own retry.
    private fun send(
        chatGuid: String,
        message: MadridMessage,
        fromKeyboard: Boolean,
        balloonBundleId: String? = null,
        done: () -> Unit = {},
    ) {
        main.post {
            val args = mapOf(
                "chatGuid" to chatGuid,
                "fromKeyboard" to fromKeyboard,
                "balloonBundleId" to balloonBundleId,
                "url" to message.url,
                "session" to message.session,
                "ldText" to message.ldText,
                "caption" to message.caption,
                "imageBase64" to message.imageBase64,
            )
            channel?.invokeMethod("send", args, object : MethodChannel.Result {
                // Dart answers false for a message it dropped, which OpenPigeon must not be told was sent
                override fun success(result: Any?) {
                    if (result == true) {
                        scope.launch { done() }
                    } else {
                        Log.w(TAG, "Dart did not take the OpenPigeon message")
                    }
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
    /// [balloonBundleId] is the opened game's own, so its turns go out under the id the session was started with.
    private fun messageHandle(chatGuid: String, balloonBundleId: String?) = object : IMessageViewHandle.Stub() {
        override fun updateMessage(message: MadridMessage?, callback: ITaskCompleteCallback?) {
            if (message == null) return
            send(chatGuid, message, fromKeyboard = false, balloonBundleId = balloonBundleId) {
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

    private class ViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
            ExtensionView(context, viewId, args as? Map<*, *> ?: emptyMap<Any, Any>())
    }

    private class ExtensionView(
        private val context: Context,
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
        private val userCount = (args["userCount"] as? Number)?.toInt() ?: 2

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
                show(it.keyboardOpened(viewCallback, keyboardHandle, userCount))
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
            withExtension(context.applicationContext) { it.keyboardClosed() }
        }
    }
}
