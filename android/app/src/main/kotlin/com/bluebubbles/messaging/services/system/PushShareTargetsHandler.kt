package com.bluebubbles.messaging.services.system

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.MainActivity
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import com.bluebubbles.messaging.utils.ContactNotificationHelper
import com.bluebubbles.messaging.utils.Utils
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Create android share sheet targets
class PushShareTargetsHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "push-share-targets"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val name: String = call.argument("title")!!
        val guid: String = call.argument("guid")!!
        val icon: ByteArray? = call.argument("icon")
        val nativeContactId: String? = call.argument("native_contact_id")
        pushShareTarget(context, name, guid, icon, nativeContactId)
        result.success(null)
    }

    fun pushShareTarget(
        context: Context,
        name: String,
        guid: String,
        icon: ByteArray?,
        nativeContactId: String? = null,
    ) {
        pushShareTarget(
            context,
            name,
            guid,
            icon,
            ContactNotificationHelper.resolveContactInfo(context, nativeContactId),
        )
    }

    internal fun pushShareTarget(
        context: Context,
        name: String,
        guid: String,
        icon: ByteArray?,
        contactInfo: ContactNotificationHelper.ContactInfo,
    ) {
        val adaptiveIcon = if ((icon?.size ?: 0) == 0) null else Utils.getAdaptiveIconFromByteArray(icon!!)

        Log.d(Constants.logTag, "Creating intent for shortcut with name $name")
        val contactCategories = setOf(Constants.categoryTextShareTarget)
        val launcherIntent = Intent(context, MainActivity::class.java)
            .putExtra("chatGuid", guid)
            .putExtra("bubble", false)
            .setAction(Intent.ACTION_DEFAULT)
        val person = ContactNotificationHelper.buildPerson(name, adaptiveIcon, contactInfo)

        Log.d(Constants.logTag, "Creating and pushing shortcut for $name")
        val shortcut = ShortcutInfoCompat.Builder(context, guid)
            .setShortLabel(name)
            .setIntent(launcherIntent)
            .setCategories(contactCategories)
            .setLongLived(true)
            .setIsConversation()
            .setPerson(person)
        if (adaptiveIcon != null) {
            shortcut.setIcon(adaptiveIcon)
        }

        ShortcutManagerCompat.pushDynamicShortcut(context, shortcut.build())
    }
}