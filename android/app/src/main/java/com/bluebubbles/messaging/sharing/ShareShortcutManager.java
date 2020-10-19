package com.bluebubbles.messaging;

import android.content.Context;

import androidx.core.content.pm.ShortcutInfoCompat;
import androidx.core.content.pm.ShortcutManagerCompat;

import java.util.ArrayList;

public class ShareShortcutManager {
    private static final int MAX_SHORTCUTS = 4;

    private static final String CATEGORY_SHARE_TARGET = "com.bluebubble.messaging.sharingshortcut";

    public void publishShareTarget(Context context) {
        ArrayList<ShortcutInfoCompat> shortcuts = new ArrayList<>();

        for(int i = 0; i < shortcuts.size(); i++) {
//            shortcuts.add();
        }

        ShortcutManagerCompat.addDynamicShortcuts(context, shortcuts);

    }
}
