package com.bluebubbles.messaging;

import hrx.plugin.monet.MonetApplication;
import io.flutter.plugin.common.PluginRegistry;

/*
 * MonetApplication extends FlutterApplication, and enables
 * support for getting a monet palette from the wallpaper
 * on devices running lower than android 8.
 */
public class Application extends MonetApplication implements PluginRegistry.PluginRegistrantCallback {

    private PluginRegistry.PluginRegistrantCallback callback;
    PluginRegistry.PluginRegistrantCallback getCallback()  {
       return callback;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        callback = this;
    }

    @Override
    public void registerWith(PluginRegistry registry) {

    }
}
