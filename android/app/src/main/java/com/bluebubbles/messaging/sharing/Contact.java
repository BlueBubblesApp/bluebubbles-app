package com.bluebubbles.messaging.sharing;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.Icon;
import android.os.Build;

import androidx.annotation.RequiresApi;
import androidx.core.graphics.drawable.IconCompat;

import com.bluebubbles.messaging.helpers.HelperUtils;

import java.util.ArrayList;

public class Contact {
    public String name;
    public String id;
    public byte[] icon;

    @RequiresApi(api = Build.VERSION_CODES.M)
    public Contact(String name, String id, byte[] icon) {
        this.name = name;
        this.id = id;
        this.icon = icon;
    }

    public IconCompat getIcon() {
        Bitmap bmp = BitmapFactory.decodeByteArray(icon, 0, icon.length);
        return IconCompat.createWithAdaptiveBitmap(bmp);
    }

}
