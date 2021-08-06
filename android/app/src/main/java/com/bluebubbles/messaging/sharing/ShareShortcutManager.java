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
import com.bluebubbles.messaging.MainActivity;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

public class ShareShortcutManager {
    private static final String CATEGORY_SHARE_TARGET = "com.bluebubbles.messaging.directshare.category.TEXT_SHARE_TARGET";

    public static void publishShareTarget(Context context, Contact contact) {

        // Category that our sharing shortcuts will be assigned to
        Set<String> contactCategories = new HashSet<>();
        contactCategories.add(CATEGORY_SHARE_TARGET);

        Intent staticLauncherShortcutIntent = new Intent(context, MainActivity.class)
            .putExtra("chatGuid", contact.id)
            .putExtra("bubble", false)
            .setType("DirectShare")
            .setAction(Intent.ACTION_DEFAULT);

        @SuppressLint("RestrictedApi")
        ShortcutInfoCompat shortcut = new ShortcutInfoCompat.Builder(context, contact.id)
                .setShortLabel(contact.name)
                .setIcon(contact.getIcon())
                .setIntent(staticLauncherShortcutIntent)
                .setCategories(contactCategories)
                .setLongLived(true)
                .setPerson(new Person.Builder()
                        .setName(contact.name)
                        .build())
                .build();
        ShortcutManagerCompat.pushDynamicShortcut(context, shortcut);
    }
}
