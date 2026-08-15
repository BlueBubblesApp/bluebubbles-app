package com.bluebubbles.messaging

class Constants {
    companion object {
        const val logTag: String = "BlueBubblesApp"
        const val methodChannel = "com.bluebubbles.messaging"
        const val categoryTextShareTarget = "com.bluebubbles.messaging.directshare.category.TEXT_SHARE_TARGET"

        // App Actions capabilities declared in res/xml/shortcuts.xml. Dynamic shortcuts are
        // bound to these so Assistant/Gemini can ground a spoken name ("...message to Mom")
        // against the conversations that actually exist on this device.
        const val sendMessageCapability = "actions.intent.SEND_MESSAGE"
        const val createMessageCapability = "actions.intent.CREATE_MESSAGE"
        const val recipientNameParameter = "message.recipient.name"
        const val googleDuoPackageName = "com.google.android.apps.tachyon"
        const val newMessageNotificationTag = "com.bluebubbles.messaging.NEW_MESSAGE_NOTIFICATION"
        const val newFaceTimeNotificationTag = "com.bluebubbles.messaging.NEW_FACETIME_NOTIFICATION"
        const val notificationGroupKey = "com.bluebubbles.messaging.NOTIFICATION_GROUP_NEW_MESSAGES"
        const val foregroundServiceNotificationChannel = "com.bluebubbles.messaging.foreground_service"
        const val foregroundServiceNotificationId = 1
        const val dartWorkerTag = "DartWorker"
        const val pendingIntentOpenChatOffset = 0
        const val pendingIntentMarkReadOffset = 100000
        const val pendingIntentOpenBubbleOffset = 200000
        const val pendingIntentDeleteNotificationOffset = 300000
        const val pendingIntentAnswerFaceTimeOffset = -100000
        const val pendingIntentDeclineFaceTimeOffset = -200000
        const val notificationListenerRequestCode = 1000
        const val dartWorkerNotificationId = 1000000
    }
}

