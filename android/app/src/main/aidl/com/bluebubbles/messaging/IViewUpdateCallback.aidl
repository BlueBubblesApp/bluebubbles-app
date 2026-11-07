// IViewUpdateCallback.aidl
package com.bluebubbles.messaging;

import android.widget.RemoteViews;

// Declare any non-default types here with import statements

oneway interface IViewUpdateCallback {
    void updateView(in RemoteViews views);
}