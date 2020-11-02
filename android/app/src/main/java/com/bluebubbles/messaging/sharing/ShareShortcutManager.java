package com.bluebubbles.messaging.sharing;

import android.content.Context;
import android.content.Intent;

import androidx.core.app.Person;
import androidx.core.content.pm.ShortcutInfoCompat;
import androidx.core.content.pm.ShortcutManagerCompat;
import androidx.core.graphics.drawable.IconCompat;

import com.bluebubbles.messaging.R;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

public class ShareShortcutManager {
    private static final int MAX_SHORTCUTS = 1;

    private static final String CATEGORY_SHARE_TARGET = "com.bluebubble.messaging.sharingshortcut";

    public static void publishShareTarget(Context context) {
        ArrayList<ShortcutInfoCompat> shortcuts = new ArrayList<>();

        // Category that our sharing shortcuts will be assigned to
        Set<String> contactCategories = new HashSet<>();
        contactCategories.add(CATEGORY_SHARE_TARGET);

        // Adding maximum number of shortcuts to the list
        for (int id = 0; id < MAX_SHORTCUTS; ++id) {

            Intent staticLauncherShortcutIntent = new Intent(Intent.ACTION_DEFAULT);

            shortcuts.add(new ShortcutInfoCompat.Builder(context, Integer.toString(id))
                    .setShortLabel(String.valueOf(id))
                    .setIcon(IconCompat.createWithResource(context, R.mipmap.ic_launcher))
                    .setIntent(staticLauncherShortcutIntent)
                    .setCategories(contactCategories)
                    .setLongLived(true)
                    .setPerson(new Person.Builder()
                            .setName(String.valueOf(id))
                            .build())
                    .build());
        }


        ShortcutManagerCompat.addDynamicShortcuts(context, shortcuts);

    }


}
