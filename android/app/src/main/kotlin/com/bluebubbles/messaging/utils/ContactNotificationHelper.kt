package com.bluebubbles.messaging.utils

import android.content.Context
import android.net.Uri
import android.provider.ContactsContract
import android.util.Log
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat
import com.bluebubbles.messaging.Constants

/**
 * Links BlueBubbles notifications to Android Contacts so **favorite** senders can
 * break through system DND without putting the whole app on the DND override list.
 *
 * Only contacts marked as Favorites in the device contacts app (the [ContactsContract.Contacts.STARRED]
 * flag — Samsung Contacts "Favorites" tab, Google Contacts starred) get a contact URI and
 * [Person.setImportant]. Other matched contacts still notify when DND is off, but will not
 * bypass DND even if they appear in the phone-call DND override list.
 *
 * All message notifications use [PARENT_CHANNEL_ID] so the tone set under
 * BlueBubbles → Notifications → New Messages is always used.
 */
object ContactNotificationHelper {
    const val PARENT_CHANNEL_ID = "com.bluebubbles.new_messages"

    /** Result of a single contacts DB lookup (lookup URI + favorite status). */
    internal data class ContactInfo(val lookupUri: Uri?, val isFavorite: Boolean)

    /**
     * Resolves contact metadata once per notification. Callers can pass the result to
     * multiple [buildPerson] invocations (e.g. sender + conversation shortcut).
     */
    internal fun resolveContactInfo(context: Context, nativeContactId: String?): ContactInfo {
        if (nativeContactId.isNullOrBlank()) return ContactInfo(null, false)
        val contactId = nativeContactId.toLongOrNull() ?: return ContactInfo(null, false)

        return try {
            val cursor = context.contentResolver.query(
                ContactsContract.Contacts.CONTENT_URI,
                arrayOf(
                    ContactsContract.Contacts._ID,
                    ContactsContract.Contacts.LOOKUP_KEY,
                    ContactsContract.Contacts.STARRED,
                ),
                "${ContactsContract.Contacts._ID} = ?",
                arrayOf(contactId.toString()),
                null,
            ) ?: return ContactInfo(null, false)

            cursor.use {
                if (!it.moveToFirst()) return ContactInfo(null, false)
                val id = it.getLong(it.getColumnIndexOrThrow(ContactsContract.Contacts._ID))
                val lookupKey = it.getString(it.getColumnIndexOrThrow(ContactsContract.Contacts.LOOKUP_KEY))
                val isFavorite = it.getInt(it.getColumnIndexOrThrow(ContactsContract.Contacts.STARRED)) == 1
                val info = ContactInfo(ContactsContract.Contacts.getLookupUri(id, lookupKey), isFavorite)
                when {
                    info.isFavorite && info.lookupUri != null -> Log.d(
                        Constants.logTag,
                        "Favorite contact linked for DND bypass: ${info.lookupUri}",
                    )
                    info.lookupUri != null -> Log.d(
                        Constants.logTag,
                        "Contact matched but not a favorite — notifying without DND bypass link",
                    )
                }
                info
            }
        } catch (e: SecurityException) {
            Log.w(Constants.logTag, "Contacts permission missing; skipping contact info for notification", e)
            ContactInfo(null, false)
        } catch (e: Exception) {
            Log.w(Constants.logTag, "Failed to resolve contact info for notification", e)
            ContactInfo(null, false)
        }
    }

    /** Builds a [Person] after resolving contact info (standalone / MethodChannel path). */
    fun buildPerson(
        context: Context,
        name: String,
        icon: IconCompat?,
        nativeContactId: String?,
    ): Person = buildPerson(name, icon, resolveContactInfo(context, nativeContactId))

    /** Builds a [Person] from pre-resolved [contactInfo] (no extra contacts DB query). */
    internal fun buildPerson(
        name: String,
        icon: IconCompat?,
        contactInfo: ContactInfo,
    ): Person {
        val builder = Person.Builder().setName(name)
        if (icon != null) {
            builder.setIcon(icon)
        }

        if (contactInfo.isFavorite && contactInfo.lookupUri != null) {
            builder.setUri(contactInfo.lookupUri.toString())
            builder.setImportant(true)
        }

        return builder.build()
    }
}