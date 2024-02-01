package com.bluebubbles.messaging.services.system

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import com.bluebubbles.messaging.Constants
import com.bluebubbles.messaging.MainActivity
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
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
        pushShareTarget(context, name, guid, icon)
        result.success(null)
    }

    fun pushShareTarget(context: Context, name: String, guid: String, icon: ByteArray?) {
        val adaptiveIcon = if ((icon?.size ?: 0) == 0) null else Utils.getAdaptiveIconFromByteArray(icon!!)

        Log.d(Constants.logTag, "Creating intent for shortcut with name $name")
        val contactCategories = setOf(Constants.categoryTextShareTarget)
        val launcherIntent = Intent(context, MainActivity::class.java)
            .putExtra("chatGuid", guid)
            .putExtra("bubble", false)
            .setAction(Intent.ACTION_DEFAULT)
        val person = Person.Builder().setName(name)
        if (adaptiveIcon != null) {
            person.setIcon(adaptiveIcon)
        }

        Log.d(Constants.logTag, "Creating and pushing shortcut for $name")
        val shortcut = ShortcutInfoCompat.Builder(context, guid)
            .setShortLabel(name)
            .setIntent(launcherIntent)
            .setCategories(contactCategories)
            .setLongLived(true)
            .setIsConversation()
            .setPerson(person.build())
        if (adaptiveIcon != null) {
            shortcut.setIcon(adaptiveIcon)
        }

        ShortcutManagerCompat.pushDynamicShortcut(context, shortcut.build())
    }
}