package com.bluebubbles.messaging.services.backend_ui_interop

import android.content.Context
import android.util.Log
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.MainActivity.Companion.engine
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
import com.bluebubbles.messaging.services.system.StartGoogleDuoRequestHandler
import com.bluebubbles.messaging.services.foreground.StartForegroundServiceHandler
import com.bluebubbles.messaging.services.foreground.StopForegroundServiceHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MethodCallHandler {
    companion object {
        var getNotificationListenerResult: MethodChannel.Result? = null

        /// Send a method call back to Dart (app must be launched, otherwise use the DartWorker!)
        fun invokeMethod(method: String, arguments: Map<String, Any>) {
            if (engine != null) {
                MethodChannel(engine!!.dartExecutor.binaryMessenger, Constants.methodChannel).invokeMethod(method, arguments)
            }
        }
    }

    fun methodCallHandler(call: MethodCall, result: MethodChannel.Result, context: Context) {
        Log.d(Constants.logTag, "Received new method call from Dart with method ${call.method}")
        when(call.method) {
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
            CheckChromeOsHandler.tag -> CheckChromeOsHandler().handleMethodCall(call, result, context)
            NotificationListenerPermissionRequestHandler.tag -> {
                getNotificationListenerResult = result
                NotificationListenerPermissionRequestHandler().handleMethodCall(call, result, context)
            }
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
                Log.d(Constants.logTag, error)
                result.error("500", error, null)
            }
        }
    }
}