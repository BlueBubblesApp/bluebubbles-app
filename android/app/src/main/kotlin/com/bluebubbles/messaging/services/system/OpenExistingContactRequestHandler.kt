package com.bluebubbles.messaging.services.system

import android.content.Context
import android.content.Intent
import android.provider.ContactsContract
import androidx.core.content.ContentResolverCompat
import com.bluebubbles.messaging.models.MethodCallHandlerImpl
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Open an existing contact page
class OpenExistingContactRequestHandler: MethodCallHandlerImpl() {
    companion object {
        const val tag = "view-contact-form"
    }

    override fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
        context: Context
    ) {
        val contactId: String = call.argument("id")!!
        // perform a manual lookup even though we have a contact ID because there is no guarantee the actual content URI will be based off the ID
        val cursor = ContentResolverCompat.query(context.contentResolver, ContactsContract.Contacts.CONTENT_URI, null, "${ContactsContract.Contacts._ID} = ?", arrayOf(contactId), null, null)
        if (cursor != null) {
            cursor.moveToFirst()
            val contactIdLong: Long = cursor.getLong(cursor.getColumnIndexOrThrow(ContactsContract.Contacts._ID))
            val lookupId: String = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.Contacts.LOOKUP_KEY))
            val uri = ContactsContract.Contacts.getLookupUri(contactIdLong, lookupId)
            val intent = Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, ContactsContract.Contacts.CONTENT_ITEM_TYPE)
                // Problem in Android 4.0+ (https://developer.android.com/training/contacts-provider/modify-data#add-the-navigation-flag)
                .putExtra("finishActivityOnSaveCompleted", true)
            context.startActivity(intent)
            result.success(null)
        } else {
            result.error("500", "Failed to find contact!", null)
        }
    }
}