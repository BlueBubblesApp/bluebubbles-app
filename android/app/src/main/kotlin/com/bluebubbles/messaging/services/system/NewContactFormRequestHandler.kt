package com.bluebubbles.messaging.services.system

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.provider.ContactsContract
import java.io.ByteArrayOutputStream
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
        call.argument<String>("name")?.let { intent.putExtra(ContactsContract.Intents.Insert.NAME, it) }
        call.argument<ByteArray>("avatar")?.let { photo(it) }?.let {
            val row = ContentValues().apply {
                put(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Photo.CONTENT_ITEM_TYPE)
                put(ContactsContract.CommonDataKinds.Photo.PHOTO, it)
            }
            intent.putParcelableArrayListExtra(ContactsContract.Intents.Insert.DATA, arrayListOf(row))
        }
        context.startActivity(intent)
        result.success(null)
    }

    /// Shrinks a photo to fit in the intent, which shares the 1 MB binder transaction limit.
    private fun photo(bytes: ByteArray): ByteArray? {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        val scale = 512f / maxOf(bitmap.width, bitmap.height)
        val scaled = if (scale < 1) {
            Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true)
        } else {
            bitmap
        }
        return ByteArrayOutputStream().also { scaled.compress(Bitmap.CompressFormat.JPEG, 90, it) }.toByteArray()
    }
}