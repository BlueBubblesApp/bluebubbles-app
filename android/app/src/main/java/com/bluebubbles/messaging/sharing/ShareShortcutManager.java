package com.bluebubbles.messaging.sharing;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import androidx.core.app.Person;
import androidx.core.content.pm.ShortcutInfoCompat;
import androidx.core.content.pm.ShortcutManagerCompat;
import androidx.core.graphics.drawable.IconCompat;

import com.bluebubbles.messaging.R;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

public class ShareShortcutManager {
    private static final int MAX_SHORTCUTS = 4;

    private static final String CATEGORY_SHARE_TARGET = "com.bluebubbles.messaging.category.TEXT_SHARE_TARGET";

    @SuppressLint("RestrictedApi")
    public static void publishShareTarget(Context context, ArrayList<Contact> contacts) {
        ArrayList<ShortcutInfoCompat> shortcuts = new ArrayList<>();

        // Category that our sharing shortcuts will be assigned to
        Set<String> contactCategories = new HashSet<>();
        contactCategories.add(CATEGORY_SHARE_TARGET);

        // Adding maximum number of shortcuts to the list
        for (int i = 0; i < contacts.size(); ++i) {
            Contact contact = contacts.get(i);

            Intent staticLauncherShortcutIntent = new Intent(Intent.ACTION_DEFAULT);

            shortcuts.add(new ShortcutInfoCompat.Builder(context, contact.id)
                    .setShortLabel(contact.name)
                    .setIcon(IconCompat.createFromIcon(contact.icon))
                    .setIntent(staticLauncherShortcutIntent)
                    .setCategories(contactCategories)
                    .setLongLived(true)
                    .setPerson(new Person.Builder()
                            .setName(contact.name)
                            .build())
                    .build());
        }

        ShortcutManagerCompat.removeAllDynamicShortcuts(context);
        ShortcutManagerCompat.addDynamicShortcuts(context, shortcuts);
    }
}
