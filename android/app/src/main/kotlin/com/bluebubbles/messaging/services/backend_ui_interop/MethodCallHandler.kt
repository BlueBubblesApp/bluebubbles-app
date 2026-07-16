package com.bluebubbles.messaging.services.backend_ui_interop

import android.content.Context
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.utils.PersistentLog
import com.bluebubbles.messaging.MainActivity
import com.bluebubbles.messaging.services.filesystem.GetContentUriPathHandler
import com.bluebubbles.messaging.services.firebase.FirebaseAuthHandler
import com.bluebubbles.messaging.services.firebase.FirebaseDeleteTokenHandler
import com.bluebubbles.messaging.services.firebase.ServerUrlRequestHandler
import com.bluebubbles.messaging.services.firebase.UpdateNextRestartHandler
import com.bluebubbles.messaging.services.notifications.CreateIncomingFaceTimeNotification
import com.bluebubbles.messaging.services.notifications.CreateIncomingMessageNotification
import com.bluebubbles.messaging.services.notifications.DeleteNotificationHandler
import com.bluebubbles.messaging.services.notifications.NotificationChannelHandler
import com.bluebubbles.messaging.services.notifications.NotificationListenerPermissionRequestHandler
import com.bluebubbles.messaging.services.notifications.StartNotificationListenerHandler
import com.bluebubbles.messaging.services.notifications.UnifiedPushHandler
import com.bluebubbles.messaging.services.system.BrowserLaunchRequestHandler
import com.bluebubbles.messaging.services.system.CheckChromeOsHandler
import com.bluebubbles.messaging.services.system.NewContactFormRequestHandler
import com.bluebubbles.messaging.services.system.OpenCalendarRequestHandler
import com.bluebubbles.messaging.services.system.OpenConversationNotificationSettingsHandler
import com.bluebubbles.messaging.services.system.OpenExistingContactRequestHandler
import com.bluebubbles.messaging.services.system.PushShareTargetsHandler
import com.bluebubbles.messaging.services.system.SaveFileToDownloadsHandler
import com.bluebubbles.messaging.services.system.StartGoogleDuoRequestHandler
import com.bluebubbles.messaging.services.foreground.StartForegroundServiceHandler
import com.bluebubbles.messaging.services.foreground.StopForegroundServiceHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MethodCallHandler {
    companion object {
        private val notificationResultLock = Any()
        private var notificationListenerResult: MethodChannel.Result? = null
        private val fireAndForgetResult = object : MethodChannel.Result {
            override fun success(result: Any?) {
                // Intentionally ignored. Fire-and-forget calls are acknowledged immediately.
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                Log.w(Constants.logTag, "Ignored late error reply for fire-and-forget method: $errorCode $errorMessage")
            }

            override fun notImplemented() {
                Log.w(Constants.logTag, "Ignored late notImplemented reply for fire-and-forget method")
            }
        }

        private val fireAndForgetTags = setOf(
            UnifiedPushHandler.tag,
            FirebaseDeleteTokenHandler.tag,
            NotificationChannelHandler.tag,
            UpdateNextRestartHandler.tag,
            BrowserLaunchRequestHandler.tag,
            PushShareTargetsHandler.tag,
            NewContactFormRequestHandler.tag,
            OpenExistingContactRequestHandler.tag,
            OpenCalendarRequestHandler.tag,
            StartGoogleDuoRequestHandler.tag,
            OpenConversationNotificationSettingsHandler.tag,
            CreateIncomingMessageNotification.tag,
            CreateIncomingFaceTimeNotification.tag,
            DeleteNotificationHandler.tag,
            StartForegroundServiceHandler.tag,
            StopForegroundServiceHandler.tag,
        )

        fun setNotificationListenerResult(result: MethodChannel.Result) {
            synchronized(notificationResultLock) {
                notificationListenerResult = result
            }
        }

        fun consumeNotificationListenerResult(): MethodChannel.Result? {
            synchronized(notificationResultLock) {
                val result = notificationListenerResult
                notificationListenerResult = null
                return result
            }
        }

        fun clearNotificationListenerResult() {
            synchronized(notificationResultLock) {
                notificationListenerResult = null
            }
        }

        /// Send a method call back to Dart (app must be launched, otherwise use the DartWorker!)
        fun invokeMethod(method: String, arguments: Map<String, Any>) {
            val currentEngine = MainActivity.getEngine()
            if (currentEngine != null) {
                MethodChannel(currentEngine.dartExecutor.binaryMessenger, Constants.methodChannel).invokeMethod(method, arguments)
            }
        }
    }

    private fun dispatchHandler(call: MethodCall, result: MethodChannel.Result, context: Context) {
        when(call.method) {
            "ready" -> {
                PersistentLog.d(context, Constants.logTag, "Dart engine is ready!")
                // Only MainActivity's channel routes "ready" here. DartWorker's headless
                // engine intercepts and resolves its own "ready" handshake locally (see
                // DartWorker.initNewEngine), so this always reflects the main engine.
                MainActivity.setDartReady(true, context)
                result.success(null)
            }
            UnifiedPushHandler.tag -> UnifiedPushHandler().handleMethodCall(call, result, context)
            FirebaseAuthHandler.tag -> FirebaseAuthHandler().handleMethodCall(call, result, context)
            FirebaseDeleteTokenHandler.tag -> FirebaseDeleteTokenHandler().handleMethodCall(call, result, context)
            NotificationChannelHandler.tag -> NotificationChannelHandler().handleMethodCall(call, result, context)
            ServerUrlRequestHandler.tag -> ServerUrlRequestHandler().handleMethodCall(call, result, context)
            UpdateNextRestartHandler.tag -> UpdateNextRestartHandler().handleMethodCall(call, result, context)
            BrowserLaunchRequestHandler.tag -> BrowserLaunchRequestHandler().handleMethodCall(call, result, context)
            PushShareTargetsHandler.tag -> PushShareTargetsHandler().handleMethodCall(call, result, context)
            NewContactFormRequestHandler.tag -> NewContactFormRequestHandler().handleMethodCall(call, result, context)
            OpenExistingContactRequestHandler.tag -> OpenExistingContactRequestHandler().handleMethodCall(call, result, context)
            OpenCalendarRequestHandler.tag -> OpenCalendarRequestHandler().handleMethodCall(call, result, context)
            StartGoogleDuoRequestHandler.tag -> StartGoogleDuoRequestHandler().handleMethodCall(call, result, context)
            SaveFileToDownloadsHandler.tag -> SaveFileToDownloadsHandler().handleMethodCall(call, result, context)
            CheckChromeOsHandler.tag -> CheckChromeOsHandler().handleMethodCall(call, result, context)
            NotificationListenerPermissionRequestHandler.tag -> NotificationListenerPermissionRequestHandler().handleMethodCall(call, result, context)
            StartNotificationListenerHandler.tag -> StartNotificationListenerHandler().handleMethodCall(call, result, context)
            OpenConversationNotificationSettingsHandler.tag -> OpenConversationNotificationSettingsHandler().handleMethodCall(call, result, context)
            GetContentUriPathHandler.tag -> GetContentUriPathHandler().handleMethodCall(call, result, context)
            CreateIncomingMessageNotification.tag -> CreateIncomingMessageNotification().handleMethodCall(call, result, context)
            CreateIncomingFaceTimeNotification.tag -> CreateIncomingFaceTimeNotification().handleMethodCall(call, result, context)
            DeleteNotificationHandler.tag -> DeleteNotificationHandler().handleMethodCall(call, result, context)
            StartForegroundServiceHandler.tag -> StartForegroundServiceHandler().handleMethodCall(call, result, context)
            StopForegroundServiceHandler.tag -> StopForegroundServiceHandler().handleMethodCall(call, result, context)
            else -> {
                val error = "Could not find method call handler for ${call.method}!"
                PersistentLog.d(context, Constants.logTag, error)
                result.error("500", error, null)
            }
        }
    }

    fun methodCallHandler(call: MethodCall, result: MethodChannel.Result, context: Context) {
        PersistentLog.d(context, Constants.logTag, "Received new method call from Dart with method ${call.method}")

        if (fireAndForgetTags.contains(call.method)) {
            result.success(null)
            try {
                dispatchHandler(call, fireAndForgetResult, context)
            } catch (e: Exception) {
                PersistentLog.e(context, Constants.logTag, "Fire-and-forget method handler failed for ${call.method}", e)
            }
            return
        }

        try {
            dispatchHandler(call, result, context)
        } catch (e: Exception) {
            PersistentLog.e(context, Constants.logTag, "Method channel handler failed for ${call.method}", e)
            result.error("500", "Method channel handler failed", e.localizedMessage)
        }
    }
}