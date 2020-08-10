package com.bluebubbles.messaging;

import android.app.Activity;

import androidx.annotation.CallSuper;

import com.bluebubbles.giftextfield.GiftextfieldPlugin;

import io.flutter.app.FlutterApplication;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.view.FlutterMain;

public class Application extends FlutterApplication implements PluginRegistry.PluginRegistrantCallback {

    private PluginRegistry.PluginRegistrantCallback callback;
    PluginRegistry.PluginRegistrantCallback getCallback()  {
       return callback;
    }

//    @Override
//    @CallSuper
//    public void onCreate() {
//        super.onCreate();
//        FlutterMain.startInitialization(this);
//    }
//
//    private Activity mCurrentActivity = null;
//
//    public Activity getCurrentActivity() {
//        return mCurrentActivity;
//    }
//
//    public void setCurrentActivity(Activity mCurrentActivity) {
//        this.mCurrentActivity = mCurrentActivity;
//    }

    @Override
    public void onCreate() {
        super.onCreate();
        callback = this;
    }

    @Override
    public void registerWith(PluginRegistry registry) {

    }
}
