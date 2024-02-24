package com.bluebubbles.messaging.services.system

import android.content.Context
import android.content.Intent
import android.provider.ContactsContract
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Open the new contact form picker
class NewContactFormRequestHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "open-contact-form"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val address: String = call.argument("address")!!
        val addressType: String = call.argument("address_type")!!

        val intent = Intent(Intent.ACTION_INSERT_OR_EDIT)
            .setType(ContactsContract.Contacts.CONTENT_ITEM_TYPE)
            // Problem in Android 4.0+ (https://developer.android.com/training/contacts-provider/modify-data#add-the-navigation-flag)
            .putExtra("finishActivityOnSaveCompleted", true)
        if (addressType == "email") {
            intent.putExtra(ContactsContract.Intents.Insert.EMAIL, address)
        } else {
            intent.putExtra(ContactsContract.Intents.Insert.PHONE, address)
        }
        context.startActivity(intent)
        result.success(null)
    }
}