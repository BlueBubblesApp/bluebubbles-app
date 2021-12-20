package com.bluebubbles.messaging;

import io.flutter.app.FlutterApplication;
import io.flutter.plugin.common.PluginRegistry;

public class Application extends FlutterApplication implements PluginRegistry.PluginRegistrantCallback {

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
